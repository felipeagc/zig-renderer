usingnamespace @import("renderer");

pub const App = @This();

allocator: *Allocator,
engine: *Engine,
asset_manager: *AssetManager,
noise_pipeline: *GraphicsPipelineAsset,
post_pipeline: *GraphicsPipelineAsset,
sampler: *rg.Sampler,

graph: *rg.Graph,
noise_image_res: rg.ResourceRef,
main_pass: rg.PassRef,
backbuffer_pass: rg.PassRef,

pub fn init(allocator: *Allocator) !*App {
    var self = try allocator.create(App);
    errdefer allocator.destroy(self);

    var engine = try Engine.init(allocator);
    errdefer engine.deinit();

    var asset_manager = try AssetManager.init(engine, .{.watch = true});
    errdefer asset_manager.deinit();

    var noise_pipeline = try asset_manager.load(
        GraphicsPipelineAsset, @embedFile("../shaders/noise.hlsl"));

    var post_pipeline = try asset_manager.load(
        GraphicsPipelineAsset, @embedFile("../shaders/post.hlsl"));

    var graph = rg.Graph.create() orelse return error.InitFail;

    var depth_res = graph.addImage(&rg.GraphImageInfo{
        .aspect = rg.ImageAspect.Depth | rg.ImageAspect.Stencil,
        .format = engine.device.getSupportedDepthFormat(.D32Sfloat),
    });

    var color_res = graph.addImage(&rg.GraphImageInfo{
        .aspect = rg.ImageAspect.Color,
        .format = .Rgba8Unorm,
    });

    var main_pass = graph.addPass(.Graphics);
    graph.passUseResource(main_pass, color_res, .Undefined, .ColorAttachment);
    graph.passUseResource(main_pass, depth_res, .Undefined, .DepthStencilAttachment);

    var backbuffer_pass = graph.addPass(.Graphics);
    graph.passUseResource(backbuffer_pass, color_res, .ColorAttachment, .Sampled);

    var window_size = engine.getWindowSize();
    graph.build(
        engine.device,
        engine.main_cmd_pool,
        &rg.GraphInfo{
            .user_data = @ptrCast(*c_void, self),
            .window = &try engine.getWindowInfo(),
            .preferred_swapchain_format = .Bgra8Unorm,

            .width = window_size.width,
            .height = window_size.height,
        }
    );

    var sampler = engine.device.createSampler(&rg.SamplerInfo{
        .mag_filter = rg.Filter.Linear,
        .min_filter = rg.Filter.Linear,
        .address_mode = rg.SamplerAddressMode.Repeat,
        .border_color = rg.BorderColor.FloatTransparentBlack,
    }) orelse return error.InitFail;

    self.* = .{
        .allocator = allocator,
        .engine = engine,
        .asset_manager = asset_manager,
        .noise_pipeline = noise_pipeline,
        .post_pipeline = post_pipeline,
        .graph = graph,
        .noise_image_res = color_res,
        .main_pass = main_pass,
        .backbuffer_pass = backbuffer_pass,
        .sampler = sampler,
    };
    return self;
}


pub fn deinit(self: *App) void {
    self.engine.device.destroySampler(self.sampler);
    self.graph.destroy();
    self.asset_manager.deinit();
    self.engine.deinit();
    self.allocator.destroy(self);
}

pub fn run(self: *App) !void {
    // {
    //     var window_size = self.engine.getWindowSize();
    //     self.graph.resize(window_size.width, window_size.height);
    // }

    while (!self.engine.shouldClose()) {
        self.engine.pollEvents();

        while (self.engine.nextEvent()) |event| {
            switch (event) {
                .FramebufferResized => |resized| {
                    self.graph.resize(
                        @intCast(u32, resized.width),
                        @intCast(u32, resized.height)
                    );
                    std.log.info("window resized", .{});
                },
                else => {}
            }
        }

        self.asset_manager.refreshAssets();

        if (self.graph.beginFrame() == .ResizeNeeded) continue;
        defer self.graph.endFrame();

        {
            var cb = self.graph.beginPass(self.main_pass);
            defer self.graph.endPass(self.main_pass);

            const UniformType = extern struct {
                res: Vec2,
                time: f32,
            };

            var window_size = self.engine.getWindowSize();

            var uniform = UniformType{
                .time = @floatCast(f32, self.engine.getTime() * 5.0),
                .res = Vec2.init(
                    @intToFloat(f32, window_size.width),
                    @intToFloat(f32, window_size.height),
                ),
            };

            cb.setUniform(0, 0, @sizeOf(UniformType), @ptrCast(*c_void, &uniform));
            cb.bindPipeline(self.noise_pipeline.pipeline);
            cb.draw(3, 1, 0, 0);
        }

        {
            var cb = self.graph.beginPass(self.backbuffer_pass);
            defer self.graph.endPass(self.backbuffer_pass);

            var noise_img = self.graph.getImage(self.noise_image_res);

            cb.bindImage(0, 0, noise_img);
            cb.bindSampler(1, 0, self.sampler);
            cb.bindPipeline(self.post_pipeline.pipeline);
            cb.draw(3, 1, 0, 0);
        }
    }
}

pub fn main() !void {
    const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = try App.init(&gpa.allocator);
    defer app.deinit();

    std.time.sleep(1_000_000_000);
    try app.run();
}
