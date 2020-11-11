usingnamespace @import("./common.zig");
usingnamespace @import("./math.zig");
const Engine = @import("./Engine.zig").Engine;
const ArrayList = std.ArrayList;

usingnamespace @import("./pbr.zig");

pub const Mesh = struct {
    engine: *Engine,
    vertex_buffer: *rg.Buffer,

    index_count: usize,
    index_buffer: *rg.Buffer,

    material: Material,

    pub fn initCube(engine: *Engine, cmd_pool: *rg.CmdPool) !Mesh {
        var vertices = [8]Vertex{
            Vertex{.pos = Vec3.init( 0.5, 0.5,  0.5)},
            Vertex{.pos = Vec3.init(-0.5, 0.5,  0.5)},
            Vertex{.pos = Vec3.init(-0.5, 0.5, -0.5)},
            Vertex{.pos = Vec3.init( 0.5, 0.5, -0.5)},

            Vertex{.pos = Vec3.init( 0.5, -0.5,  0.5)},
            Vertex{.pos = Vec3.init(-0.5, -0.5,  0.5)},
            Vertex{.pos = Vec3.init(-0.5, -0.5, -0.5)},
            Vertex{.pos = Vec3.init( 0.5, -0.5, -0.5)},
        };

        var indices = [_]u32{
            0, 3, 2,
            2, 1, 0,

            6, 7, 4,
            4, 5, 6,

            6, 2, 3,
            3, 7, 6,

            7, 3, 0,
            0, 4, 7,

            4, 0, 1,
            1, 5, 4,

            5, 1, 2,
            2, 6, 5,
        };

        var vertex_buffer = engine.device.createBuffer(&rg.BufferInfo{
            .size = @sizeOf(@TypeOf(vertices)),
            .usage = rg.BufferUsage.Vertex | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        var index_buffer = engine.device.createBuffer(&rg.BufferInfo{
            .size = @sizeOf(@TypeOf(indices)),
            .usage = rg.BufferUsage.Index | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        engine.device.uploadBuffer(cmd_pool, vertex_buffer, 0, @sizeOf(@TypeOf(vertices)), &vertices[0]);
        engine.device.uploadBuffer(cmd_pool, index_buffer, 0, @sizeOf(@TypeOf(indices)), &indices[0]);

        return Mesh{
            .engine = engine,
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .index_count = indices.len,
            .material = Material.default(engine),
        };
    }

    pub fn initSphere(
        engine: *Engine,
        cmd_pool: *rg.CmdPool,
        radius: f32,
        detail: f32, // higher is more detailed
    ) !Mesh {
        var vertices = ArrayList(Vertex).init(engine.alloc);
        defer vertices.deinit();
        var indices = ArrayList(u32).init(engine.alloc);
        defer indices.deinit();

        var s: f32 = (std.math.pi * 2.0) / detail;

        var h: f32 = 0.0;
        while (h < (std.math.pi * 2.0 - s)) : (h += s) {
            var v: f32 = -std.math.pi / 2.0;
            while (v < std.math.pi / 2.0) : (v += s) {
                var v1 = Vertex{
                    .pos = Vec3
                        .init(cos(v) * cos(h), sin(v), cos(v) * sin(h))
                        .smul(radius)
                };
                var v2 = Vertex{
                    .pos = Vec3
                        .init(cos(v + s) * cos(h), sin(v + s), cos(v + s) * sin(h))
                        .smul(radius)  
                };
                var v3 = Vertex{
                    .pos = Vec3
                        .init(cos(v + s) * cos(h + s), sin(v + s), cos(v + s) * sin(h + s))
                        .smul(radius)  
                };
                var v4 = Vertex{
                    .pos = Vec3
                        .init(cos(v) * cos(h + s), sin(v), cos(v) * sin(h + s))
                        .smul(radius)  
                };

                var index_base = @intCast(u32, vertices.items.len);

                try vertices.append(v1);
                try vertices.append(v2);
                try vertices.append(v3);
                try vertices.append(v4);

                try indices.append(index_base + 0);
                try indices.append(index_base + 1);
                try indices.append(index_base + 2);
                try indices.append(index_base + 2);
                try indices.append(index_base + 3);
                try indices.append(index_base + 0);
            }
        }

        var vertices_size: usize = vertices.items.len * @sizeOf(@TypeOf(vertices.items[0]));
        var indices_size: usize = indices.items.len * @sizeOf(@TypeOf(indices.items[0]));
        std.debug.assert(vertices_size > 0);
        std.debug.assert(indices_size > 0);

        var vertex_buffer = engine.device.createBuffer(&rg.BufferInfo{
            .size = vertices_size,
            .usage = rg.BufferUsage.Vertex | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        var index_buffer = engine.device.createBuffer(&rg.BufferInfo{
            .size = indices_size,
            .usage = rg.BufferUsage.Index | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        engine.device.uploadBuffer(cmd_pool, vertex_buffer, 0, vertices_size, &vertices.items[0]);
        engine.device.uploadBuffer(cmd_pool, index_buffer, 0, indices_size, &indices.items[0]);

        return Mesh{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .index_count = indices.items.len,
            .engine = engine,
            .material = Material.default(engine),
        };
    }

    pub fn draw(
        self: *Mesh,
        cb: *rg.CmdBuffer,
        transform: ?*const Mat4,
        model_set_optional: ?u32,
        material_set_optinal: ?u32,
    ) void {
        cb.bindVertexBuffer(self.vertex_buffer, 0);
        cb.bindIndexBuffer(.Uint32, self.index_buffer, 0);

        if (model_set_optional) |model_set| {
            std.debug.assert(transform != null);
            var model: Mat4 = transform.?.*;
            cb.setUniform(0, model_set, @sizeOf(@TypeOf(model)), @ptrCast(*c_void, &model));
        }

        if (material_set_optinal) |material_set| {
            self.material.bind(cb, material_set);
        }

        cb.drawIndexed(@intCast(u32, self.index_count), 1, 0, 0, 0);
    }

    pub fn deinit(self: *Mesh) void {
        self.engine.device.destroyBuffer(self.vertex_buffer);
        self.engine.device.destroyBuffer(self.index_buffer);
    }
};
