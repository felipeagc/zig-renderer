usingnamespace @import("./common.zig");
usingnamespace @import("./math.zig");
const Engine = @import("./Engine.zig").Engine;
const PipelineAsset = @import("./PipelineAsset.zig").PipelineAsset;
const Mesh = @import("./mesh.zig").Mesh;

pub const IBLBaker = struct {
    engine: *Engine,
    irradiance_pipeline: *PipelineAsset,
    skybox_sampler: *rg.Sampler,
    cube_mesh: Mesh,
    current_mip: u32 = 0,
    current_layer: u32 = 0,
    current_dim: u32 = 0,
    current_skybox: ?*rg.Image = null,
    current_graph: ?*rg.Graph = null,
    current_offscreen_ref: ?rg.ResourceRef = null,
    current_cubemap_ref: ?rg.ResourceRef = null,

    pub fn init(engine: *Engine) !IBLBaker {
        var skybox_sampler = engine.device.createSampler(&rg.SamplerInfo{
            .anisotropy = false,
            .mag_filter = .Linear,
            .min_filter = .Linear,
            .max_lod = 1.0,
            .address_mode = .ClampToEdge,
            .border_color = .FloatOpaqueWhite,
        }) orelse return error.GpuObjectCreateError;

        return IBLBaker{
            .engine = engine,
            .irradiance_pipeline = try PipelineAsset.init(engine,
                @embedFile("../shaders/irradiance.hlsl")),
            .cube_mesh = try Mesh.initCube(engine.device),
            .skybox_sampler = skybox_sampler,
        };
    }

    pub fn deinit(self: *IBLBaker) void {
        self.engine.device.destroySampler(self.skybox_sampler);
        self.irradiance_pipeline.deinit();
        self.cube_mesh.deinit();
    }

    pub fn generateIrradiance(self: *IBLBaker, skybox: *rg.Image) !*rg.Image {
        self.current_skybox = skybox;
        defer self.current_skybox = null;

        var dim: u32 = 64;
        self.current_dim = dim;

        var format: rg.Format = .Rgba32Sfloat;

        // var mip_count: u32  = @floatToInt(u32, (std.math.floor(
        //     std.math.log2(@intToFloat(f32, dim)))) + 1);
        var mip_count: u32  = 1;

        var graph = rg.Graph.create(self.engine.device, @ptrCast(*c_void, self), null)
            orelse return error.GpuObjectCreateError;
        defer graph.destroy();

        self.current_graph = graph;
        defer self.current_graph = null;

        var offscreen_ref = graph.addImage(&rg.GraphImageInfo{
            .scaling_mode = .Absolute,
            .width = @intToFloat(f32, dim),
            .height = @intToFloat(f32, dim),
            .format = format,
            .aspect = rg.ImageAspect.Color,
        });
        self.current_offscreen_ref = offscreen_ref;

        var cubemap_image = self.engine.device.createImage(&rg.ImageInfo{
            .width = dim,
            .height = dim,
            .format = format,
            .layer_count = 6,
            .mip_count = mip_count,
            .aspect = rg.ImageAspect.Color,
            .usage = rg.ImageUsage.TransferDst | rg.ImageUsage.Sampled,
        }) orelse return error.GpuObjectCreateError;
        self.engine.device.setObjectName(.Image, cubemap_image, "Irradiance cubemap");

        self.engine.device.imageBarrier(cubemap_image, .Undefined, .TransferDst);

        var cubemap_ref = graph.addExternalImage(cubemap_image);
        self.current_cubemap_ref = cubemap_ref;

        var layer_pass = graph.addPass(.Graphics, layerPassCallback);
        graph.passUseResource(layer_pass, offscreen_ref, .Undefined, .ColorAttachment);

        var transfer_pass = graph.addPass(.Transfer, transferPassCallback);
        graph.passUseResource(transfer_pass, offscreen_ref, .ColorAttachment, .TransferSrc);
        graph.passUseResource(transfer_pass, cubemap_ref, .TransferDst, .TransferDst);

        graph.build();

        var m: u32 = 0;
        while (m < mip_count) : (m += 1) {
            var f: u32 = 0;
            while (f < 6) : (f += 1) {
                self.current_mip = m;
                self.current_layer = f;
                graph.execute();
                graph.waitAll();
            }
        }

        self.engine.device.imageBarrier(cubemap_image, .TransferDst, .Sampled);

        return cubemap_image;
    }

    fn layerPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
        var self: *IBLBaker = @ptrCast(*IBLBaker, @alignCast(@alignOf(IBLBaker), user_data));

        std.debug.assert(self.current_skybox != null);

        var uniform: extern struct {
            mvp: Mat4,
        } = .{
            .mvp = Mat4.perspective((std.math.pi / 2.0), 1.0, 0.1, 512.0)
                .mul(direction_matrices[self.current_layer]),
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

        cb.bindPipeline(self.irradiance_pipeline.pipeline);
        cb.setUniform(0, 0, @sizeOf(@TypeOf(uniform)), @ptrCast(*c_void, &uniform));
        cb.bindSampler(1, 0, self.skybox_sampler);
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
