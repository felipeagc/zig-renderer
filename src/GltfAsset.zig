usingnamespace @import("./common.zig");
usingnamespace @import("./assets.zig");
usingnamespace @import("./math.zig");
const Engine = @import("./Engine.zig").Engine;

const ArrayList = std.ArrayList;
usingnamespace @import("./cgltf.zig");
usingnamespace @import("./stb_image.zig");

const Self = @This();
pub const GltfAsset = @This();

engine: *Engine,

nodes: []Node,
root_nodes: ArrayList(usize),

meshes: []Mesh,

images: []*rg.Image,
samplers: []*rg.Sampler,
materials: []Material,

vertex_buffer: *rg.Buffer,

index_count: usize,
index_buffer: *rg.Buffer,

const Vertex = extern struct {
    pos: [3]f32,
    normal: [3]f32,
    tangent: [4]f32,
    uv: [2]f32,
};

const MaterialUniform = extern struct {
    base_color_factor: [4]f32 = [4]f32{1.0, 1.0, 1.0, 1.0},
    emissive_factor: [4]f32 = [4]f32{1.0, 1.0, 1.0, 1.0},
    metallic: f32 = 1.0,
    roughness: f32 = 1.0,
    normal_mapped: f32 = 0.0,
};

const Material = struct {
    uniform: MaterialUniform,

    albedo_image: *rg.Image,
    albedo_sampler: *rg.Sampler,

    normal_image: *rg.Image,
    normal_sampler: *rg.Sampler,

    metallic_roughness_image: *rg.Image,
    metallic_roughness_sampler: *rg.Sampler,

    occlusion_image: *rg.Image,
    occlusion_sampler: *rg.Sampler,

    emissive_image: *rg.Image,
    emissive_sampler: *rg.Sampler,
};

const Primitive = struct {
    first_index: u32,
    index_count: u32,
    vertex_count: u32,
    material_index: ?usize,
    has_indices: bool,
    is_normal_mapped: bool,
};

const Mesh = struct {
    primitives: ArrayList(Primitive),
};

const Node = struct {
    parent_index: ?usize,
    children_indices: ArrayList(usize),

    matrix: Mat4,
    mesh_index: ?usize,

    translation: Vec3,
    scale: Vec3,
    rotation: Quat,

    fn localMatrix(self: *Node) Mat4 {
        var result = self.matrix;
        result = result.scale(self.scale);
        result = result.mul(self.rotation.toMat4());
        result = result.translate(self.translation);
        return result;
    }

    // Calculate the final matrix for the node starting from its root
    fn resolveMatrix(self: *Node, asset: *GltfAsset) Mat4 {
        var m: Mat4 = self.localMatrix();
        var p: ?usize = self.parent_index;
        while (p) |parent_index| {
            m = m.mul(asset.nodes[parent_index].localMatrix());
            p = asset.nodes[parent_index].parent_index;
        }
        return m;
    }
};

pub fn init(engine: *Engine, data: []const u8) anyerror!*Self {
    const allocator = engine.alloc;

    var gltf_options = cgltf_options{ .type = cgltf_file_type.glb };
    var gltf_data: *cgltf_data = undefined;
    var result: cgltf_result = cgltf_parse(&gltf_options, data.ptr, data.len, &gltf_data);
    if (result != cgltf_result.success) return error.GltfParseError;
    defer cgltf_free(gltf_data);

    result = cgltf_load_buffers(&gltf_options, gltf_data, null);
    if (result != cgltf_result.success) return error.GltfParseError;

    var max_lod: f32 = 1.0;

    var images = try allocator.alloc(*rg.Image, gltf_data.images_count);
    for (images) |*image, i| {
        var gltf_image: *cgltf_image = &gltf_data.images[i];
        var mime_type: []const u8 = mem.span(gltf_image.mime_type);
        std.log.info("loading image {} of type \"{}\"", .{i, mime_type});

        if (mem.eql(u8, mime_type, "image/png") or
            mem.eql(u8, mime_type, "image/jpeg")) {
            var buffer = gltf_image.buffer_view.buffer;
            var offset = gltf_image.buffer_view.offset;
            var size = gltf_image.buffer_view.size;

            var buffer_data: []u8 = buffer.data[offset..offset+size];

            var width: i32 = 0;
            var height: i32 = 0;
            var n_channels: i32 = 0;
            var image_data: [*]u8 = stbi_load_from_memory(
                buffer_data.ptr,
                @intCast(i32, buffer_data.len),
                &width,
                &height,
                &n_channels,
                4,
            ) orelse return error.StbImageFail;
            defer stbi_image_free(image_data);

            assert(width > 0 and height > 0 and n_channels > 0);

            var mip_count: u32 = @floatToInt(u32, std.math.floor(
                std.math.log2(@intToFloat(f32, std.math.max(width, height))))) + 1;

            image.* = engine.device.createImage(&rg.ImageInfo{
                .width = @intCast(u32, width),
                .height = @intCast(u32, height),
                .mip_count = mip_count,
                .format = .Rgba8Unorm,
                .usage = rg.ImageUsage.TransferDst
                    | rg.ImageUsage.TransferSrc
                    | rg.ImageUsage.Sampled,
                .aspect = rg.ImageAspect.Color,
            }) orelse return error.GpuObjectCreateError;

            engine.device.uploadImage(
                &rg.ImageCopy{ .image = image.* },
                &rg.Extent3D{ 
                    .width = @intCast(u32, width),
                    .height = @intCast(u32, height),
                    .depth = 1,
                },
                @intCast(u32, 4 * width * height),
                image_data,
            );

            engine.device.imageBarrier(image.*, &rg.ImageRegion{
                .base_mip_level = 0,
                .mip_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            }, .Sampled, .TransferSrc);

            engine.device.generateMipMaps(image.*);

            max_lod = std.math.max(max_lod, @intToFloat(f32, mip_count));
        } else {
            unreachable;
        }
    }

    var samplers = try allocator.alloc(*rg.Sampler, gltf_data.samplers_count);
    for (samplers) |*sampler, i| {
        var gltf_sampler = &gltf_data.samplers[i];
        var ci = rg.SamplerInfo{
            .anisotropy = true,
            .max_anisotropy = 16.0,
            .mag_filter = .Linear,
            .min_filter = .Linear,
            .min_lod = 0.0,
            .max_lod = max_lod,
            .address_mode = .Repeat,
            .border_color = .FloatOpaqueWhite,
        };

        ci.mag_filter = switch (gltf_sampler.mag_filter) {
            0x2601 => .Linear,
            0x2600 => .Nearest,
            else => .Linear,
        };

        ci.mag_filter = switch (gltf_sampler.min_filter) {
            0x2601 => .Linear,
            0x2600 => .Nearest,
            else => .Linear,
        };

        sampler.* = engine.device.createSampler(&ci)
            orelse return error.GpuObjectCreateError;
    }

    var materials = try allocator.alloc(Material, gltf_data.materials_count);
    for (materials) |*material, i| {
        var gltf_material: *cgltf_material = &gltf_data.materials[i];
        assert(gltf_material.has_pbr_metallic_roughness != 0);

        material.* = Material{
            .uniform = .{},

            .albedo_image = engine.white_image,
            .albedo_sampler = engine.default_sampler,

            .normal_image = engine.white_image,
            .normal_sampler = engine.default_sampler,

            .metallic_roughness_image = engine.white_image,
            .metallic_roughness_sampler = engine.default_sampler,

            .occlusion_image = engine.white_image,
            .occlusion_sampler = engine.default_sampler,

            .emissive_image = engine.black_image,
            .emissive_sampler = engine.default_sampler,
        };

        if (gltf_material.pbr_metallic_roughness.base_color_texture.texture) |texture| {
            var image_index = (@ptrToInt(texture.image) - @ptrToInt(gltf_data.images))
                / @sizeOf(@TypeOf(texture.image.*));
            material.albedo_image = images[image_index];

            engine.device.setObjectName(.Image, material.albedo_image, "GLTF Image: albedo");

            if (texture.sampler) |sampler| {
                var sampler_index = (@ptrToInt(sampler) - @ptrToInt(gltf_data.samplers)) 
                    / @sizeOf(@TypeOf(sampler.*));
                material.albedo_sampler = samplers[sampler_index];
            }
        }

        if (gltf_material.normal_texture.texture) |texture| {
            var image_index = (@ptrToInt(texture.image) - @ptrToInt(gltf_data.images))
                / @sizeOf(@TypeOf(texture.image.*));
            material.normal_image = images[image_index];

            engine.device.setObjectName(.Image, material.normal_image, "GLTF Image: normal");

            if (texture.sampler) |sampler| {
                var sampler_index = (@ptrToInt(sampler) - @ptrToInt(gltf_data.samplers)) 
                    / @sizeOf(@TypeOf(sampler.*));
                material.normal_sampler = samplers[sampler_index];
            }
        }

        if (gltf_material.pbr_metallic_roughness.metallic_roughness_texture.texture) |texture| {
            var image_index = (@ptrToInt(texture.image) - @ptrToInt(gltf_data.images))
                / @sizeOf(@TypeOf(texture.image.*));
            material.metallic_roughness_image = images[image_index];

            engine.device.setObjectName(.Image, material.metallic_roughness_image, "GLTF Image: metallic roughness");

            if (texture.sampler) |sampler| {
                var sampler_index = (@ptrToInt(sampler) - @ptrToInt(gltf_data.samplers)) 
                    / @sizeOf(@TypeOf(sampler.*));
                material.metallic_roughness_sampler = samplers[sampler_index];
            }
        }

        if (gltf_material.occlusion_texture.texture) |texture| {
            var image_index = (@ptrToInt(texture.image) - @ptrToInt(gltf_data.images))
                / @sizeOf(@TypeOf(texture.image.*));
            material.occlusion_image = images[image_index];

            engine.device.setObjectName(.Image, material.occlusion_image, "GLTF Image: occlusion");

            if (texture.sampler) |sampler| {
                var sampler_index = (@ptrToInt(sampler) - @ptrToInt(gltf_data.samplers)) 
                    / @sizeOf(@TypeOf(sampler.*));
                material.occlusion_sampler = samplers[sampler_index];
            }
        }

        if (gltf_material.emissive_texture.texture) |texture|
        {
            var image_index = (@ptrToInt(texture.image) - @ptrToInt(gltf_data.images))
                / @sizeOf(@TypeOf(texture.image.*));
            material.emissive_image = images[image_index];

            engine.device.setObjectName(.Image, material.emissive_image, "GLTF Image: emissive");

            if (texture.sampler) |sampler| {
                var sampler_index = (@ptrToInt(sampler) - @ptrToInt(gltf_data.samplers)) 
                    / @sizeOf(@TypeOf(sampler.*));
                material.emissive_sampler = samplers[sampler_index];
            }
        }
    }

    var vertices = ArrayList(Vertex).init(allocator);
    defer vertices.deinit();
    var indices = ArrayList(u32).init(allocator);
    defer indices.deinit();

    var primitives = ArrayList(Primitive).init(allocator);

    var meshes = try allocator.alloc(Mesh, gltf_data.meshes_count);
    for (meshes) |*mesh, i| {
        var gltf_mesh: *cgltf_mesh = &gltf_data.meshes[i];

        var j: usize = 0;
        while (j < gltf_mesh.primitives_count) : (j += 1) {
            var primitive: *cgltf_primitive = &gltf_mesh.primitives[j];

            var index_start = indices.items.len;
            var vertex_start = vertices.items.len;

            var index_count: usize = 0;
            var vertex_count: usize = 0;

            var has_indices: bool = primitive.indices != null;

            // Vertices
            var pos_byte_stride: usize = 0;
            var pos_buffer: ?[*]u8 = null;

            var normal_byte_stride: usize = 0;
            var normal_buffer: ?[*]u8 = null;

            var tangent_byte_stride: usize = 0;
            var tangent_buffer: ?[*]u8 = null;

            var uv0_byte_stride: usize = 0;
            var uv0_buffer: ?[*]u8 = null;

            var k: usize = 0;
            while (k < primitive.attributes_count) : (k += 1) {
                switch (primitive.attributes[k].type) {
                   .position => {
                        var accessor: *cgltf_accessor = primitive.attributes[k].data;
                        var view: *cgltf_buffer_view = accessor.buffer_view;

                        pos_byte_stride = accessor.stride;
                        pos_buffer = @ptrCast([*]u8, view.buffer.data + accessor.offset + view.offset);

                        vertex_count += accessor.count;
                    },

                   .normal => {
                        var accessor: *cgltf_accessor = primitive.attributes[k].data;
                        var view: *cgltf_buffer_view = accessor.buffer_view;

                        normal_byte_stride = accessor.stride;
                        normal_buffer = @ptrCast([*]u8, view.buffer.data + accessor.offset + view.offset);
                    },

                   .tangent => {
                        var accessor: *cgltf_accessor = primitive.attributes[k].data;
                        var view: *cgltf_buffer_view = accessor.buffer_view;

                        tangent_byte_stride = accessor.stride;
                        tangent_buffer = @ptrCast([*]u8, view.buffer.data + accessor.offset + view.offset);
                    },

                   .texcoord => {
                        var accessor: *cgltf_accessor = primitive.attributes[k].data;
                        var view: *cgltf_buffer_view = accessor.buffer_view;

                        uv0_byte_stride = accessor.stride;
                        uv0_buffer = @ptrCast([*]u8, view.buffer.data + accessor.offset + view.offset);
                    },

                    else => {},
                }
            }

            try vertices.resize(vertices.items.len + vertex_count);
            var new_vertices = vertices.items[vertices.items.len - vertex_count .. vertices.items.len];

            // Position
            for (new_vertices) |*vertex, index| {
                @memcpy(
                    @ptrCast([*]u8, @alignCast(@alignOf(u8), &vertex.pos)),
                    @ptrCast([*]u8, &pos_buffer.?[index * pos_byte_stride]),
                    @sizeOf(@TypeOf(vertex.pos)));
            }

            // Normal
            if (normal_buffer) |normals| {
                for (new_vertices) |*vertex, index| {
                    @memcpy(
                        @ptrCast([*]u8, @alignCast(@alignOf(u8), &vertex.normal)),
                        @ptrCast([*]u8, &normals[index * normal_byte_stride]),
                        @sizeOf(@TypeOf(vertex.normal)));
                }
            }

            // Tangents
            if (tangent_buffer) |tangents| {
                for (new_vertices) |*vertex, index| {
                    @memcpy(
                        @ptrCast([*]u8, @alignCast(@alignOf(u8), &vertex.tangent)),
                        @ptrCast([*]u8, &tangents[index * tangent_byte_stride]),
                        @sizeOf(@TypeOf(vertex.tangent)));
                }
            }

            // UV0
            if (uv0_buffer) |uv0| {
                for (new_vertices) |*vertex, index| {
                    @memcpy(
                        @ptrCast([*]u8, @alignCast(@alignOf(u8), &vertex.uv)),
                        @ptrCast([*]u8, &uv0[index * uv0_byte_stride]),
                        @sizeOf(@TypeOf(vertex.uv)));
                }
            }

            if (has_indices) {
                var accessor: *cgltf_accessor = primitive.indices;
                var buffer_view: *cgltf_buffer_view = accessor.buffer_view;
                var buffer: *cgltf_buffer = buffer_view.buffer;

                var first_index: usize = indices.items.len;
                index_count = accessor.count;

                try indices.resize(indices.items.len + index_count);
                var new_indices = indices.items[indices.items.len - index_count .. indices.items.len];

                var data_ptr: [*]u8 = buffer.data + accessor.offset + buffer_view.offset;

                switch (accessor.component_type)
                {
                    .r_32u => {
                        var buf = @ptrCast([*]u32, @alignCast(@alignOf(u32), data_ptr));
                        for (new_indices) |*index_ptr, index| {
                            index_ptr.* = buf[index] + @intCast(u32, vertex_start);
                        }
                    },

                    .r_16u => {
                        var buf = @ptrCast([*]u16, @alignCast(@alignOf(u16), data_ptr));
                        for (new_indices) |*index_ptr, index| {
                            index_ptr.* = buf[index] + @intCast(u16, vertex_start);
                        }
                    },

                    .r_8u => {
                        var buf = @ptrCast([*]u8, @alignCast(@alignOf(u8), data_ptr));
                        for (new_indices) |*index_ptr, index| {
                            index_ptr.* = buf[index] + @intCast(u8, vertex_start);
                        }
                    },

                    else => unreachable,
                }
            }

            var new_primitive = Primitive{
                .first_index = @intCast(u32, index_start),
                .index_count = @intCast(u32, index_count),
                .vertex_count = @intCast(u32, vertex_count),
                .is_normal_mapped = normal_buffer != null and tangent_buffer != null,
                .material_index = null,
                .has_indices = has_indices,
            };

            if (primitive.material) |material|
            {
                new_primitive.material_index =
                    (@ptrToInt(primitive.material) - @ptrToInt(gltf_data.materials))
                    / @sizeOf(@TypeOf(primitive.material.*));
            }

            try primitives.append(new_primitive);
        }

        mesh.* = Mesh{ .primitives = primitives, };
    }

    var vertex_buffer_size: usize = vertices.items.len * @sizeOf(Vertex);
    var index_buffer_size: usize = indices.items.len * @sizeOf(u32);
    var index_count: usize = indices.items.len;
    assert(vertex_buffer_size > 0);

    var vertex_buffer = engine.device.createBuffer(&rg.BufferInfo{
        .usage = rg.BufferUsage.Vertex | rg.BufferUsage.TransferDst,
        .memory = .Device,
        .size = vertex_buffer_size,
    }) orelse return error.GpuObjectCreateError;

    var index_buffer = engine.device.createBuffer(&rg.BufferInfo{
        .usage = rg.BufferUsage.Index | rg.BufferUsage.TransferDst,
        .memory = .Device,
        .size = index_buffer_size,
    }) orelse return error.GpuObjectCreateError;

    engine.device.uploadBuffer(vertex_buffer, 0, vertex_buffer_size, @ptrCast(*c_void, vertices.items.ptr));
    engine.device.uploadBuffer(index_buffer, 0, index_buffer_size, @ptrCast(*c_void, indices.items.ptr));

    var nodes = try allocator.alloc(Node, gltf_data.nodes_count);
    for (nodes) |*node, i| {
        var gltf_node: *cgltf_node = &gltf_data.nodes[i];

        node.* = Node{
            .parent_index = null,
            .children_indices = ArrayList(usize).init(allocator),

            .matrix = Mat4.identity,
            .mesh_index = null,

            .translation = Vec3.zero,
            .scale = Vec3.one,
            .rotation = Quat.identity,
        };

        if (gltf_node.has_translation != 0) {
            node.translation.x = gltf_node.translation[0];
            node.translation.y = gltf_node.translation[1];
            node.translation.z = gltf_node.translation[2];
        }

        if (gltf_node.has_scale != 0) {
            node.scale.x = gltf_node.scale[0];
            node.scale.y = gltf_node.scale[1];
            node.scale.z = gltf_node.scale[2];
        }

        if (gltf_node.has_rotation != 0) {
            node.rotation.x = gltf_node.rotation[0];
            node.rotation.y = gltf_node.rotation[1];
            node.rotation.z = gltf_node.rotation[2];
            node.rotation.w = gltf_node.rotation[3];
        }

        if (gltf_node.has_matrix != 0) {
            @memcpy(
                @ptrCast([*]u8, &node.matrix),
                @ptrCast([*]u8, &gltf_node.rotation),
                @sizeOf([16]f32));
        }

        if (gltf_node.mesh) |mesh| {
            var mesh_index = (@ptrToInt(mesh) - @ptrToInt(gltf_data.meshes))
                / @sizeOf(@TypeOf(mesh.*));
            node.mesh_index = mesh_index;
        }

        if (gltf_node.parent) |parent| {
            node.parent_index = (@ptrToInt(parent) - @ptrToInt(gltf_data.nodes))
                / @sizeOf(@TypeOf(parent.*));
        }
    }

    // Add children / root nodes
    var root_nodes = ArrayList(usize).init(allocator);

    for (nodes) |*node, i| {
        if (node.parent_index) |parent_index| {
            try nodes[parent_index].children_indices.append(i);
        } else {
            try root_nodes.append(i);
        }
    }

    var self = try allocator.create(@This());
    self.* = Self{
        .engine = engine,
        .images = images,
        .samplers = samplers,
        .materials = materials,
        .meshes = meshes,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .index_count = indices.items.len,
        .nodes = nodes,
        .root_nodes = root_nodes,
    };

    for (self.nodes) |*node| {
        node.matrix = node.resolveMatrix(self);
    }

    return self;
}

pub fn deinit(self_opaque: *c_void) void {
    var self = @ptrCast(*Self, @alignCast(@alignOf(@This()), self_opaque));

    self.engine.device.destroyBuffer(self.vertex_buffer);
    self.engine.device.destroyBuffer(self.index_buffer);

    for (self.images) |image| {
        self.engine.device.destroyImage(image);
    }
    self.engine.alloc.free(self.images);

    for (self.samplers) |sampler| {
        self.engine.device.destroySampler(sampler);
    }
    self.engine.alloc.free(self.samplers);

    self.engine.alloc.free(self.materials);

    for (self.meshes) |mesh| {
        mesh.primitives.deinit();
    }
    self.engine.alloc.free(self.meshes);

    for (self.nodes) |node| {
        node.children_indices.deinit();
    }
    self.engine.alloc.free(self.nodes);

    self.root_nodes.deinit();

    self.engine.alloc.destroy(self);
}

fn drawNode(
    self: *Self,
    cb: *rg.CmdBuffer,
    node: *Node,
    transform: *const Mat4,
    model_set: u32,
    material_set_maybe: ?u32) void
{
    if (node.mesh_index) |mesh_index| {
        var mesh: *Mesh = &self.meshes[mesh_index];

        for (mesh.primitives.items) |primitive| {
            var model: Mat4 = node.matrix.mul(transform.*);
            cb.setUniform(0, model_set, @sizeOf(@TypeOf(model)), @ptrCast(*c_void, &model));

            if (material_set_maybe) |material_set| {
                if (primitive.material_index) |material_index| {
                    var material = &self.materials[material_index];
                    material.uniform.normal_mapped = 
                        if (primitive.is_normal_mapped) 1.0 else 0.0;

                    cb.setUniform(0, material_set,
                        @sizeOf(@TypeOf(material.uniform)),
                        @ptrCast(*c_void, &material.uniform));
                    cb.bindSampler(1, material_set, material.albedo_sampler);
                    cb.bindImage(2, material_set, material.albedo_image);
                    cb.bindImage(3, material_set, material.normal_image);
                    cb.bindImage(4, material_set, material.metallic_roughness_image);
                    cb.bindImage(5, material_set, material.occlusion_image);
                    cb.bindImage(6, material_set, material.emissive_image);
                }
            }

            if (primitive.has_indices) {
                cb.drawIndexed(primitive.index_count, 1, primitive.first_index, 0, 0);
            } else {
                cb.draw(primitive.vertex_count, 1, 0, 0);
            }
        }
    }

    for (node.children_indices.items) |child_index| {
        var child: *Node = &self.nodes[child_index];
        self.drawNode(cb, child, transform, model_set, material_set_maybe);
    }
}

pub fn draw(
    self: *Self,
    cb: *rg.CmdBuffer,
    transform: *const Mat4,
    model_set: u32,
    material_set: ?u32) void
{
    cb.bindVertexBuffer(self.vertex_buffer, 0);
    cb.bindIndexBuffer(.Uint32, self.index_buffer, 0);
    for (self.root_nodes.items) |node_index| {
        var node = &self.nodes[node_index];
        self.drawNode(cb, node, transform, model_set, material_set);
    }
}
