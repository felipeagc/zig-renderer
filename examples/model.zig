usingnamespace @import("renderer");

pub const App = @This();

allocator: *Allocator,
engine: *Engine,
asset_manager: *AssetManager,
model_pipeline: *PipelineAsset,
graph: *rg.Graph,

model: *GltfAsset,
camera: CameraUniform,

const CameraUniform = extern struct {
    pos: Vec4 = Vec4.init(0, 0, 0, 1),
    view: Mat4 = Mat4.identity,
    proj: Mat4 = Mat4.identity,
};

fn onResize(user_data: ?*c_void, width: i32, height: i32) void {
    if (user_data == null) return;
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(App), user_data));
    self.graph.resize();

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

    var model_pipeline = try asset_manager.load(
        PipelineAsset, @embedFile("../shaders/model.hlsl"));

    var model = try asset_manager.load(
        GltfAsset, @embedFile("../assets/DamagedHelmet.glb"));

    var graph = rg.Graph.create(
        engine.device, @ptrCast(*c_void, self), &try engine.getWindowInfo())
        orelse return error.InitFail;

    var depth_res = graph.addImage(&rg.GraphImageInfo{
        .aspect = rg.ImageAspect.Depth | rg.ImageAspect.Stencil,
        .format = .D24UnormS8Uint,
    });

    var main_pass = graph.addPass(mainPassCallback);
    graph.addPassOutput(main_pass, depth_res, .DepthStencilAttachment);

    graph.build();

    self.* = .{
        .allocator = allocator,
        .engine = engine,
        .asset_manager = asset_manager,
        .model_pipeline = model_pipeline,
        .graph = graph,
        .model = model,
        .camera = .{},
    };
    return self;
}


pub fn deinit(self: *App) void {
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

    cb.bindPipeline(self.model_pipeline.pipeline);
    cb.setUniform(0, 0, @sizeOf(@TypeOf(self.camera)), @ptrCast(*c_void, &self.camera));
    
    self.model.draw(cb, &Mat4.identity, 1, 2);
}

pub fn run(self: *App) !void {
    while (!self.engine.shouldClose()) {
        self.engine.pollEvents();
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
