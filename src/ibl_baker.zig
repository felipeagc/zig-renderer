usingnamespace @import("./common.zig");
usingnamespace @import("./math.zig");
const Engine = @import("./Engine.zig").Engine;
const PipelineAsset = @import("./PipelineAsset.zig").PipelineAsset;
const Mesh = @import("./mesh.zig").Mesh;

const CubemapType = enum {
    Irradiance,
    Radiance,
};

pub const IBLBaker = struct {
    engine: *Engine,
    irradiance_pipeline: *PipelineAsset,
    radiance_pipeline: *PipelineAsset,
    brdf_pipeline: *PipelineAsset,
    skybox_sampler: ?*rg.Sampler = null,
    cube_mesh: Mesh,
    current_mip: u32 = 0,
    current_layer: u32 = 0,
    current_dim: u32 = 0,
    current_skybox: ?*rg.Image = null,
    current_graph: ?*rg.Graph = null,
    current_offscreen_ref: ?rg.ResourceRef = null,
    current_cubemap_ref: ?rg.ResourceRef = null,
    current_type: ?CubemapType = null,
    current_mip_count: u32 = 0,

    pub fn init(engine: *Engine) !IBLBaker {
        return IBLBaker{
            .engine = engine,
            .irradiance_pipeline = try PipelineAsset.init(engine,
                @embedFile("../shaders/irradiance.hlsl")),
            .radiance_pipeline = try PipelineAsset.init(engine,
                @embedFile("../shaders/radiance.hlsl")),
            .brdf_pipeline = try PipelineAsset.init(engine,
                @embedFile("../shaders/brdf.hlsl")),
            .cube_mesh = try Mesh.initCube(engine.device),
        };
    }

    pub fn deinit(self: *IBLBaker) void {
        if (self.skybox_sampler) |sampler| {
            self.engine.device.destroySampler(sampler);
            self.skybox_sampler = null;
        }
        self.irradiance_pipeline.deinit();
        self.radiance_pipeline.deinit();
        self.brdf_pipeline.deinit();
        self.cube_mesh.deinit();
    }

    pub fn generateBrdfLut(self: *IBLBaker) !*rg.Image {
        std.log.info("Generating BRDF LuT", .{});

        var graph = rg.Graph.create()
            orelse return error.GpuObjectCreateError;
        defer graph.destroy();

        self.current_graph = graph;
        defer self.current_graph = null;

        self.current_dim = 512;

        const main_callback = struct {
            fn callback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
                var ibl_baker: *IBLBaker = @ptrCast(
                    *IBLBaker, @alignCast(@alignOf(IBLBaker), user_data));

                cb.bindPipeline(ibl_baker.brdf_pipeline.pipeline);
                cb.draw(3, 1, 0, 0);
            }
        }.callback;

        var brdf_image = self.engine.device.createImage(&rg.ImageInfo{
            .width = self.current_dim,
            .height = self.current_dim,
            .format = .Rg32Sfloat,
            .aspect = rg.ImageAspect.Color,
            .usage = rg.ImageUsage.ColorAttachment | rg.ImageUsage.Sampled,
        }) orelse return error.GpuObjectCreateError;
        self.engine.device.setObjectName(
            .Image,
            brdf_image,
            "BRDF LuT");

        var brdf_ref = graph.addExternalImage(brdf_image);

        var main_pass = graph.addPass(.Graphics, main_callback);
        graph.passUseResource(main_pass, brdf_ref, .Undefined, .ColorAttachment);

        graph.build(self.engine.device, &rg.GraphInfo{
            .user_data = @ptrCast(*c_void, self),

            .width = 0,
            .height = 0,
        });

        graph.execute();
        graph.waitAll();

        return brdf_image;
    }

    pub fn generateCubemap(
        self: *IBLBaker,
        comptime cubemap_type: CubemapType,
        skybox: *rg.Image,
        out_mip_levels: ?*u32
    ) !*rg.Image {
        switch (cubemap_type) {
            .Radiance => std.log.info("Generating radiance cubemap", .{}),
            .Irradiance => std.log.info("Generating irradiance cubemap", .{}),
        }

        self.current_type = cubemap_type;
        self.current_skybox = skybox;
        defer self.current_skybox = null;

        self.current_dim = switch (cubemap_type) {
            .Irradiance => 64,
            .Radiance => 512,
        };

        var format: rg.Format = switch (cubemap_type) {
            .Irradiance => .Rgba32Sfloat,
            .Radiance => .Rgba16Sfloat,
        };

        self.current_mip_count = @floatToInt(u32, std.math.floor(
            std.math.log2(@intToFloat(f32, self.current_dim)))) + 1;

        if (self.skybox_sampler) |sampler| {
            self.engine.device.destroySampler(sampler);
        }

        self.skybox_sampler = self.engine.device.createSampler(&rg.SamplerInfo{
            .anisotropy = true,
            .max_anisotropy = 16.0,
            .mag_filter = .Linear,
            .min_filter = .Linear,
            .min_lod = 0.0,
            .max_lod = @intToFloat(f32, self.current_mip_count),
            .address_mode = .ClampToEdge,
            .border_color = .FloatOpaqueWhite,
        }) orelse return error.GpuObjectCreateError;

        if (out_mip_levels) |out_mips| {
            out_mips.* = self.current_mip_count;
        }

        var graph = rg.Graph.create() orelse return error.GpuObjectCreateError;
        defer graph.destroy();

        self.current_graph = graph;
        defer self.current_graph = null;

        var offscreen_ref = graph.addImage(&rg.GraphImageInfo{
            .scaling_mode = .Absolute,
            .width = @intToFloat(f32, self.current_dim),
            .height = @intToFloat(f32, self.current_dim),
            .format = format,
            .aspect = rg.ImageAspect.Color,
        });
        self.current_offscreen_ref = offscreen_ref;

        var cubemap_image = self.engine.device.createImage(&rg.ImageInfo{
            .width = self.current_dim,
            .height = self.current_dim,
            .format = format,
            .layer_count = 6,
            .mip_count = self.current_mip_count,
            .aspect = rg.ImageAspect.Color,
            .usage = rg.ImageUsage.TransferDst | rg.ImageUsage.Sampled,
        }) orelse return error.GpuObjectCreateError;
        self.engine.device.setObjectName(
            .Image,
            cubemap_image,
            if (cubemap_type == .Irradiance) "Irradiance cubemap" else "Radiance cubemap");

        self.engine.device.imageBarrier(cubemap_image, &rg.ImageRegion{
            .base_mip_level = 0,
            .mip_count = self.current_mip_count,
            .base_array_layer = 0,
            .layer_count = 6,
        }, .Undefined, .TransferDst);

        var cubemap_ref = graph.addExternalImage(cubemap_image);
        self.current_cubemap_ref = cubemap_ref;

        var layer_pass = graph.addPass(.Graphics, layerPassCallback);
        graph.passUseResource(layer_pass, offscreen_ref, .Undefined, .ColorAttachment);

        var transfer_pass = graph.addPass(.Transfer, transferPassCallback);
        graph.passUseResource(transfer_pass, offscreen_ref, .ColorAttachment, .TransferSrc);
        graph.passUseResource(transfer_pass, cubemap_ref, .TransferDst, .TransferDst);

        graph.build(self.engine.device, &rg.GraphInfo{
            .user_data = @ptrCast(*c_void, self),

            .width = 0,
            .height = 0,
        });

        var m: u32 = 0;
        while (m < self.current_mip_count) : (m += 1) {
            var f: u32 = 0;
            while (f < 6) : (f += 1) {
                self.current_mip = m;
                self.current_layer = f;
                graph.execute();
                graph.waitAll();
            }
        }

        self.engine.device.imageBarrier(cubemap_image, &rg.ImageRegion{
            .base_mip_level = 0,
            .mip_count = self.current_mip_count,
            .base_array_layer = 0,
            .layer_count = 6,
        }, .TransferDst, .Sampled);

        return cubemap_image;
    }

    fn layerPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
        var self: *IBLBaker = @ptrCast(*IBLBaker, @alignCast(@alignOf(IBLBaker), user_data));

        std.debug.assert(self.current_skybox != null);

        var uniform: extern struct {
            mvp: Mat4,
            roughness: f32,
        } = .{
            .mvp = Mat4.perspective((std.math.pi / 2.0), 1.0, 0.1, 512.0)
                .mul(direction_matrices[self.current_layer]),
            .roughness = @intToFloat(f32, self.current_mip)
                / (@intToFloat(f32, self.current_mip_count - 1)),
        };

        var mip_dim: u32 = self.current_dim >> @intCast(u5, self.current_mip);

        cb.setViewport(&rg.Viewport{
            .x = 0.0,
            .y = 0.0,
            .width = @intToFloat(f32, mip_dim),
            .height = @intToFloat(f32, mip_dim),
            .min_depth = 0.0,
            .max_depth = 1.0,
        });

        cb.setScissor(&rg.Rect2D{
            .offset = .{.x = 0, .y = 0,},
            .extent = .{.width = mip_dim, .height = mip_dim,}
        });

        switch (self.current_type.?) {
            .Irradiance => cb.bindPipeline(self.irradiance_pipeline.pipeline),
            .Radiance => cb.bindPipeline(self.radiance_pipeline.pipeline),
        }
        cb.setUniform(0, 0, @sizeOf(@TypeOf(uniform)), @ptrCast(*c_void, &uniform));
        cb.bindSampler(1, 0, self.skybox_sampler.?);
        cb.bindImage(2, 0, self.current_skybox.?);

        self.cube_mesh.draw(cb);
    }

    fn transferPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
        var self: *IBLBaker = @ptrCast(*IBLBaker, @alignCast(@alignOf(IBLBaker), user_data));

        var graph = self.current_graph.?;
        var cubemap_ref = self.current_cubemap_ref.?;
        var offscreen_ref = self.current_offscreen_ref.?;

        var offscreen_image = graph.getImage(offscreen_ref);
        var cubemap_image = graph.getImage(cubemap_ref);

        var mip_dim: u32 = self.current_dim >> @intCast(u5, self.current_mip);

        cb.copyImageToImage(
            &rg.ImageCopy{
                // Source
                .image = offscreen_image,
                .mip_level = 0,
                .array_layer = 0,
            },
            &rg.ImageCopy{
                // Destination
                .image = cubemap_image,
                .mip_level = self.current_mip,
                .array_layer = self.current_layer,
            },
            rg.Extent3D{
                .width = mip_dim,
                .height = mip_dim,
                .depth = 1,
            },
        );
    }
};

const direction_matrices = [6]Mat4{
    Mat4{
        .cols = .{
            .{0.0, 0.0, -1.0, 0.0},
            .{0.0, -1.0, 0.0, 0.0},
            .{-1.0, 0.0, 0.0, 0.0},
            .{0.0, 0.0, 0.0, 1.0},
        }
    },
    Mat4{
        .cols = .{
            .{0.0, 0.0, 1.0, 0.0},
            .{0.0, -1.0, 0.0, 0.0},
            .{1.0, 0.0, 0.0, 0.0},
            .{0.0, 0.0, 0.0, 1.0},
        }
    },
    Mat4{
        .cols = .{
            .{1.0, 0.0, 0.0, 0.0},
            .{0.0, 0.0, -1.0, 0.0},
            .{0.0, 1.0, 0.0, 0.0},
            .{0.0, 0.0, 0.0, 1.0},
        }
    },
    Mat4{
        .cols = .{
            .{1.0, 0.0, 0.0, 0.0},
            .{0.0, 0.0, 1.0, 0.0},
            .{0.0, -1.0, 0.0, 0.0},
            .{0.0, 0.0, 0.0, 1.0},
        }
    },
    Mat4{
        .cols = .{
            .{1.0, 0.0, 0.0, 0.0},
            .{0.0, -1.0, 0.0, 0.0},
            .{0.0, 0.0, -1.0, 0.0},
            .{0.0, 0.0, 0.0, 1.0},
        }
    },
    Mat4{
        .cols = .{
            .{-1.0, 0.0, 0.0, 0.0},
            .{0.0, -1.0, 0.0, 0.0},
            .{0.0, 0.0, 1.0, 0.0},
            .{0.0, 0.0, 0.0, 1.0},
        }
    },
};
