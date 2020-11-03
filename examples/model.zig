usingnamespace @import("renderer");

pub const App = @This();

allocator: *Allocator,
engine: *Engine,
asset_manager: *AssetManager,

model_pipeline: *GraphicsPipelineAsset,
skybox_pipeline: *GraphicsPipelineAsset,
graph: *rg.Graph,

model: *GltfAsset,
skybox_image: *ImageAsset,
irradiance_image: *rg.Image,
radiance_image: *rg.Image,
brdf_image: *rg.Image,
radiance_sampler: *rg.Sampler,
irradiance_sampler: *rg.Sampler,
camera: Camera,
cube_mesh: Mesh,

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

        var aspect = @intToFloat(f32, window_size.width)
            / @intToFloat(f32, window_size.height);

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
    self.graph.resize(@intCast(u32, width), @intCast(u32, height));

    std.log.info("window resized", .{});
}

pub fn init(allocator: *Allocator) !*App {
    var self = try allocator.create(App);
    errdefer allocator.destroy(self);

    var engine = try Engine.init(allocator);
    // errdefer engine.deinit();
    engine.user_data = @ptrCast(*c_void, self);
    engine.on_resize = onResize;
    engine.setCursorEnabled(false);

    var asset_manager = try AssetManager.init(engine);
    errdefer asset_manager.deinit();

    var graph = rg.Graph.create() orelse return error.InitFail;

    var depth_res = graph.addImage(&rg.GraphImageInfo{
        .aspect = rg.ImageAspect.Depth | rg.ImageAspect.Stencil,
        .format = engine.device.getSupportedDepthFormat(),
    });

    var main_pass = graph.addPass(.Graphics, mainPassCallback);

    graph.passUseResource(main_pass, depth_res, .Undefined, .DepthStencilAttachment);
    var window_size = engine.getWindowSize();
    graph.build(engine.device, &rg.GraphInfo{
        .user_data = @ptrCast(*c_void, self),
        .window = &try engine.getWindowInfo(),

        .width = window_size.width,
        .height = window_size.height,
    });

    var ibl_baker = try IBLBaker.init(engine);
    defer ibl_baker.deinit();

    var skybox_image = try asset_manager.loadFileZstd(ImageAsset, "assets/papermill.ktx.zst");
    engine.device.setObjectName(.Image, skybox_image.image, "Skybox image");
    var irradiance_mip_levels: u32 = undefined;
    var irradiance_image = try ibl_baker.generateCubemap(.Irradiance, skybox_image.image, &irradiance_mip_levels);
    var radiance_mip_levels: u32 = undefined;
    var radiance_image = try ibl_baker.generateCubemap(.Radiance, skybox_image.image, &radiance_mip_levels);
    var brdf_image = try ibl_baker.generateBrdfLut();

    var irradiance_sampler = engine.device.createSampler(&rg.SamplerInfo{
        .anisotropy = true,
        .max_anisotropy = 16.0,
        .min_filter = .Linear,
        .mag_filter = .Linear,
        .min_lod = 0.0,
        .max_lod = @intToFloat(f32, irradiance_mip_levels),
        .address_mode = .ClampToEdge,
        .border_color = .FloatOpaqueWhite,
    }) orelse return error.GpuObjectCreateError;

    var radiance_sampler = engine.device.createSampler(&rg.SamplerInfo{
        .anisotropy = true,
        .max_anisotropy = 16.0,
        .min_filter = .Linear,
        .mag_filter = .Linear,
        .min_lod = 0.0,
        .max_lod = @intToFloat(f32, radiance_mip_levels),
        .address_mode = .ClampToEdge,
        .border_color = .FloatOpaqueWhite,
    }) orelse return error.GpuObjectCreateError;

    self.* = .{
        .allocator = allocator,
        .engine = engine,
        .asset_manager = asset_manager,

        .graph = graph,
        .camera = .{},
        .cube_mesh = try Mesh.initCube(engine.device),
        .model_pipeline = try asset_manager.loadFile(GraphicsPipelineAsset, "shaders/model.hlsl"),
        .skybox_pipeline = try asset_manager.loadFile(GraphicsPipelineAsset, "shaders/skybox.hlsl"),
        .model = try asset_manager.loadFile(GltfAsset, "assets/DamagedHelmet.glb"),
        .skybox_image = skybox_image,
        .irradiance_image = irradiance_image,
        .radiance_image = radiance_image,
        .brdf_image = brdf_image,
        .radiance_sampler = radiance_sampler,
        .irradiance_sampler = irradiance_sampler,
    };
    return self;
}

pub fn deinit(self: *App) void {
    self.engine.device.destroyImage(self.irradiance_image);
    self.engine.device.destroyImage(self.radiance_image);
    self.engine.device.destroyImage(self.brdf_image);
    self.engine.device.destroySampler(self.radiance_sampler);
    self.engine.device.destroySampler(self.irradiance_sampler);
    self.cube_mesh.deinit();
    self.graph.destroy();
    self.asset_manager.deinit();
    self.engine.deinit();
    self.allocator.destroy(self);
}

fn mainPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(App), user_data));

    self.camera.update(self.engine, @floatCast(f32, self.delta_time));

    cb.bindPipeline(self.skybox_pipeline.pipeline);
    cb.setUniform(0, 0,
        @sizeOf(@TypeOf(self.camera.uniform)),
        @ptrCast(*c_void, &self.camera.uniform));
    cb.bindSampler(0, 1, self.radiance_sampler);
    cb.bindImage(1, 1, self.radiance_image);
    self.cube_mesh.draw(cb);

    cb.bindPipeline(self.model_pipeline.pipeline);
    cb.setUniform(0, 0,
        @sizeOf(@TypeOf(self.camera.uniform)),
        @ptrCast(*c_void, &self.camera.uniform));

    cb.bindSampler(0, 1, self.irradiance_sampler);
    cb.bindSampler(1, 1, self.radiance_sampler);
    cb.bindImage(2, 1, self.irradiance_image);
    cb.bindImage(3, 1, self.radiance_image);
    cb.bindImage(4, 1, self.brdf_image);
    
    self.model.draw(cb, &Mat4.identity, 2, 3);
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
