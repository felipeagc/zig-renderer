usingnamespace @import("renderer");

pub const App = @This();

allocator: *Allocator,
engine: *Engine,
asset_manager: *AssetManager,
noise_pipeline: *GraphicsPipelineAsset,
post_pipeline: *GraphicsPipelineAsset,
graph: *rg.Graph,
noise_image_res: rg.ResourceRef,
sampler: *rg.Sampler,

fn onResize(user_data: ?*c_void, width: i32, height: i32) void {
    if (user_data == null) return;
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(App), user_data));
    self.graph.resize(@intCast(u32, width), @intCast(u32, height));

    std.log.info("window resized", .{});
}

pub fn init(allocator: *Allocator) !*App {
    var self = try allocator.create(App);
    errdefer allocator.destroy(self);

    var engine = try Engine.init(allocator);
    errdefer engine.deinit();
    engine.user_data = @ptrCast(*c_void, self);
    engine.on_resize = onResize;

    var asset_manager = try AssetManager.init(engine, .{.watch = true});
    errdefer asset_manager.deinit();

    var noise_pipeline = try asset_manager.loadFile(
        GraphicsPipelineAsset, "./shaders/noise.hlsl");

    var post_pipeline = try asset_manager.loadFile(
        GraphicsPipelineAsset, "./shaders/post.hlsl");

    var graph = rg.Graph.create() orelse return error.InitFail;

    var depth_res = graph.addImage(&rg.GraphImageInfo{
        .aspect = rg.ImageAspect.Depth | rg.ImageAspect.Stencil,
        .format = engine.device.getSupportedDepthFormat(),
    });

    var color_res = graph.addImage(&rg.GraphImageInfo{
        .aspect = rg.ImageAspect.Color,
        .format = .Rgba8Unorm,
    });

    var main_pass = graph.addPass(.Graphics, mainPassCallback);
    graph.passUseResource(main_pass, color_res, .Undefined, .ColorAttachment);
    graph.passUseResource(main_pass, depth_res, .Undefined, .DepthStencilAttachment);

    var backbuffer_pass = graph.addPass(.Graphics, backbufferPassCallback);
    graph.passUseResource(backbuffer_pass, color_res, .ColorAttachment, .Sampled);

    var window_size = engine.getWindowSize();
    graph.build(
        engine.device,
        engine.main_cmd_pool,
        &rg.GraphInfo{
            .user_data = @ptrCast(*c_void, self),
            .window = &try engine.getWindowInfo(),

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

fn mainPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(App), user_data));

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

fn backbufferPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(App), user_data));

    var noise_img = self.graph.getImage(self.noise_image_res);

    cb.bindImage(0, 0, noise_img);
    cb.bindSampler(1, 0, self.sampler);
    cb.bindPipeline(self.post_pipeline.pipeline);
    cb.draw(3, 1, 0, 0);
}

pub fn run(self: *App) !void {
    while (!self.engine.shouldClose()) {
        self.engine.pollEvents();
        self.asset_manager.refreshAssets();
        self.graph.execute();
    }
}

pub fn main() !void {
    const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = try App.init(&gpa.allocator);
    defer app.deinit();

    try app.run();
}
