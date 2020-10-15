usingnamespace @import("renderer");

pub const App = @This();

allocator: *Allocator,
engine: *Engine,
asset_manager: *AssetManager,
model_pipeline: *PipelineAsset,
graph: *rg.Graph,

model: *GltfAsset,
camera: Camera,

last_time: f64 = 0.0,
delta_time: f64 = 0.0,

const Camera = struct {
    uniform: extern struct {
        pos: Vec4 = Vec4.init(0, 0, 0, 1),
        view: Mat4 = Mat4.identity,
        proj: Mat4 = Mat4.identity,
    } = .{},

    yaw: f32 = 0,
    pitch: f32 = 0,

    pos: Vec3 = Vec3.zero,

    speed: f32 = 2,

    near: f32 = 0.1,
    far: f32 = 300.0,
    fovy: f32 = 75.0 * (std.math.pi / 180.0),

    prev_x: f64 = 0,
    prev_y: f64 = 0,

    sensitivity: f32 = 0.14,

    fn update(self: *@This(), engine: *Engine, delta_time: f32) void {
        var cursor_pos = engine.getCursorPos();
        var window_size = engine.getWindowSize();

        var aspect = @intToFloat(f32, window_size.width) / @intToFloat(f32, window_size.height);

        var dx = cursor_pos.x - self.prev_x;
        var dy = cursor_pos.y - self.prev_y;

        self.prev_x = cursor_pos.x;
        self.prev_y = cursor_pos.y;

        self.yaw -= @floatCast(f32, dx) * self.sensitivity * (std.math.pi / 180.0);
        self.pitch -= @floatCast(f32, dy) * self.sensitivity * (std.math.pi / 180.0);
        self.pitch = clamp(self.pitch, -89.0 * (std.math.pi / 180.0), 89.0 * (std.math.pi / 180.0));

        var front = Vec3.init(
            sin(self.yaw) * cos(self.pitch),
            sin(self.pitch),
            cos(self.yaw) * cos(self.pitch),
        ).normalize();

        var right = front.cross(Vec3.init(0, 1, 0)).normalize();
        var up = right.cross(front).normalize();

        var delta: f32 = self.speed * delta_time;
        if (engine.getKeyState(Key.W)) {
            self.pos = self.pos.add(front.smul(delta));
        }
        if (engine.getKeyState(Key.S)) {
            self.pos = self.pos.sub(front.smul(delta));
        }
        if (engine.getKeyState(Key.A)) {
            self.pos = self.pos.sub(right.smul(delta));
        }
        if (engine.getKeyState(Key.D)) {
            self.pos = self.pos.add(right.smul(delta));
        }

        self.uniform.pos = Vec4.init(
            self.pos.x,
            self.pos.y,
            self.pos.z,
            1.0,
        );

        self.uniform.view = Mat4.lookAt(self.pos, self.pos.add(front), up);
        self.uniform.proj = Mat4.perspective(self.fovy, aspect, self.near, self.far);

        var correction = Mat4{
            .cols = .{
                .{1.0,  0.0, 0.0, 0.0},
                .{0.0, -1.0, 0.0, 0.0},
                .{0.0,  0.0, 0.5, 0.0},
                .{0.0,  0.0, 0.5, 1.0},
            }
        };

        self.uniform.proj = correction.mul(self.uniform.proj);
    }
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
    engine.setCursorEnabled(false);

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

    self.camera.update(self.engine, @floatCast(f32, self.delta_time));

    cb.bindPipeline(self.model_pipeline.pipeline);
    cb.setUniform(0, 0,
        @sizeOf(@TypeOf(self.camera.uniform)),
        @ptrCast(*c_void, &self.camera.uniform));
    
    self.model.draw(cb, &Mat4.identity, 1, 2);
}

pub fn run(self: *App) !void {
    while (!self.engine.shouldClose()) {
        self.engine.pollEvents();
        self.graph.execute();

        if (self.last_time > 0) {
            self.delta_time = self.engine.getTime() - self.last_time;
        }
        self.last_time = self.engine.getTime();
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