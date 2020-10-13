usingnamespace @import("renderer");

pub const App = @This();

allocator: *Allocator,
engine: *Engine,
asset_manager: *AssetManager,
noise_pipeline: *PipelineAsset,
post_pipeline: *PipelineAsset,
graph: *rg.Graph,
noise_image_res: rg.ResourceRef,
sampler: *rg.Sampler,

fn onResize(user_data: ?*c_void, width: i32, height: i32) void {
    if (user_data == null) return;
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(*App), user_data));
    rg.graphResize(self.graph);

    std.log.info("window resized", .{});
}

pub fn init(allocator: *Allocator) !*App {
    var self = try allocator.create(App);
    errdefer allocator.destroy(self);

    var engine = try Engine.init(allocator);
    errdefer engine.deinit();
    engine.user_data = @ptrCast(*c_void, self);
    engine.on_resize = onResize;

    var asset_manager = try AssetManager.init(engine);
    errdefer asset_manager.deinit();

    var noise_pipeline = try asset_manager.load(
        PipelineAsset, @embedFile("../shaders/noise.hlsl"));

    var post_pipeline = try asset_manager.load(
        PipelineAsset, @embedFile("../shaders/post.hlsl"));

    var graph = rg.graphCreate(
        engine.device, @ptrCast(*c_void, self), &try engine.getWindowInfo())
        orelse return error.InitFail;

    var depth_res = rg.graphAddImage(graph, &rg.GraphImageInfo{
        .aspect = @enumToInt(rg.ImageAspect.Depth) | @enumToInt(rg.ImageAspect.Stencil),
        .format = .D24UnormS8Uint,
    });

    var color_res = rg.graphAddImage(graph, &rg.GraphImageInfo{
        .aspect = @enumToInt(rg.ImageAspect.Color),
        .format = .Rgba8Unorm,
    });

    var main_pass = rg.graphAddPass(graph, mainPassCallback);
    rg.graphAddPassOutput(graph, main_pass, color_res, .ColorAttachment);
    rg.graphAddPassOutput(graph, main_pass, depth_res, .DepthStencilAttachment);

    var backbuffer_pass = rg.graphAddPass(graph, backbufferPassCallback);
    rg.graphAddPassInput(graph, main_pass, color_res, .Sampled);

    rg.graphBuild(graph);

    var sampler = rg.samplerCreate(engine.device, &rg.SamplerInfo{
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
    rg.samplerDestroy(self.engine.device, self.sampler);
    rg.graphDestroy(self.graph);
    self.asset_manager.deinit();
    self.engine.deinit();
    self.allocator.destroy(self);
}

fn mainPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(*App), user_data));

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

    rg.cmdSetUniform(cb, 0, 0, @sizeOf(UniformType), @ptrCast(*c_void, &uniform));
    rg.cmdBindPipeline(cb, self.noise_pipeline.pipeline);
    rg.cmdDraw(cb, 3, 1, 0, 0);
}

fn backbufferPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(*App), user_data));

    var noise_img = rg.graphGetImage(self.graph, self.noise_image_res);

    rg.cmdBindImage(cb, 0, 0, noise_img);
    rg.cmdBindSampler(cb, 1, 0, self.sampler);
    rg.cmdBindPipeline(cb, self.post_pipeline.pipeline);
    rg.cmdDraw(cb, 3, 1, 0, 0);
}

pub fn run(self: *App) !void {
    while (!self.engine.shouldClose()) {
        self.engine.pollEvents();
        rg.graphExecute(self.graph);
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
