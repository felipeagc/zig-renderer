usingnamespace @import("renderer");

pub const App = @This();

allocator: *Allocator,
engine: *Engine,
asset_manager: *AssetManager,

model_pipeline: *GraphicsPipelineAsset,
atmosphere_sky_pipeline: *GraphicsPipelineAsset,
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
outer_atm_mesh: Mesh,
inner_atm_mesh: Mesh,

last_time: f64 = 0.0,
delta_time: f64 = 0.0,

sun_angle: f64 = std.math.pi*0.8,

const world_inner_radius = 50.0;
const world_outer_radius = (10.25/10.0) * world_inner_radius;

const Atmosphere = extern struct {
    const Kr = 0.0025; // Rayleigh scattering constant
    const Km = 0.001; // Mie scattering constant
    const ESun = 20.0; // Sun brightness constant
    const rayleigh_scale_depth = 0.25;
    const mie_scale_depth = 0.1;

    sun_pos: Vec4,

    inv_wave_length4: Vec4 = Vec4.init(
        1.0 / std.math.pow(f32, 0.650, 4),
        1.0 / std.math.pow(f32, 0.570, 4),
        1.0 / std.math.pow(f32, 0.475, 4),
        1.0,
    ),

    camera_height: f32,
    camera_height_sq: f32,
    outer_radius: f32,
    outer_radius_sq: f32,
    inner_radius: f32,
    inner_radius_sq: f32,
    KrESun: f32 = Kr * ESun,
    KmESun: f32 = Km * ESun,
    Kr4PI: f32 = Kr * 4.0 * std.math.pi,
    Km4PI: f32 = Km * 4.0 * std.math.pi,
    scale: f32,
    scale_over_scale_depth: f32,
    g: f32 = -0.99, // The Mie phase asymmetry factor
    g_sq: f32 = -0.99 * -0.99,

    pub fn init(params: struct {
        camera_pos: Vec3,
        sun_pos: Vec3,
        inner_radius: f32,
        outer_radius: f32,
    }) @This() {
        return @This() {
            .sun_pos = Vec4.init(
                params.sun_pos.x,
                params.sun_pos.y,
                params.sun_pos.z,
                1.0
            ),
            .camera_height = params.camera_pos.norm(),
            .camera_height_sq = params.camera_pos.norm() * params.camera_pos.norm(),
            .inner_radius = params.inner_radius,
            .inner_radius_sq = params.inner_radius * params.inner_radius,
            .outer_radius = params.outer_radius,
            .outer_radius_sq = params.outer_radius * params.outer_radius,
            .scale = 1.0 / (params.outer_radius - params.inner_radius),
            .scale_over_scale_depth = (1.0 / (params.outer_radius - params.inner_radius))
                / rayleigh_scale_depth,
        };
    }
};

const Camera = struct {
    uniform: extern struct {
        pos: Vec4 = Vec4.init(0, 0, 0, 1),
        view: Mat4 = Mat4.identity,
        proj: Mat4 = Mat4.identity,
    } = .{},

    yaw: f32 = 0,
    pitch: f32 = 0,

    pos: Vec3 = Vec3.init(0.0, world_inner_radius + 1.0, 0.0),

    speed: f32 = 1.0,

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

        if (!engine.getCursorEnabled()) {
            var dx = cursor_pos.x - self.prev_x;
            var dy = cursor_pos.y - self.prev_y;

            self.prev_x = cursor_pos.x;
            self.prev_y = cursor_pos.y;

            self.yaw -= @floatCast(f32, dx) * self.sensitivity * (std.math.pi / 180.0);
            self.pitch -= @floatCast(f32, dy) * self.sensitivity * (std.math.pi / 180.0);
            self.pitch = clamp(self.pitch, -89.0 * (std.math.pi / 180.0), 89.0 * (std.math.pi / 180.0));
        }

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
}

fn onKeyPress(user_data: ?*c_void, key: Key, action: Action, mods: u32) void {
    if (user_data == null) return;
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(App), user_data));

}

pub fn init(allocator: *Allocator) !*App {
    var self = try allocator.create(App);
    errdefer allocator.destroy(self);

    var engine = try Engine.init(allocator);
    // errdefer engine.deinit();
    engine.setCursorEnabled(false);

    var asset_manager = try AssetManager.init(engine, .{.watch = true});
    errdefer asset_manager.deinit();

    var graph = rg.Graph.create() orelse return error.InitFail;

    var depth_res = graph.addImage(&rg.GraphImageInfo{
        .aspect = rg.ImageAspect.Depth | rg.ImageAspect.Stencil,
        .format = engine.device.getSupportedDepthFormat(),
    });

    var main_pass = graph.addPass(.Graphics, mainPassCallback);

    graph.passUseResource(main_pass, depth_res, .Undefined, .DepthStencilAttachment);
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

    var ibl_baker = try IBLBaker.init(engine);
    defer ibl_baker.deinit();

    var skybox_image = try asset_manager.loadFile(ImageAsset, "assets/papermill.ktx.zst");
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
        .cube_mesh = try Mesh.initCube(engine, engine.main_cmd_pool),
        .outer_atm_mesh = try Mesh.initSphere(engine, engine.main_cmd_pool, world_outer_radius, 360.0),
        .inner_atm_mesh = try Mesh.initSphere(engine, engine.main_cmd_pool, world_inner_radius, 360.0),
        .model_pipeline = try asset_manager.loadFile(GraphicsPipelineAsset, "shaders/model.hlsl"),
        .atmosphere_sky_pipeline =
            try asset_manager.loadFile(GraphicsPipelineAsset, "shaders/atmosphere_sky.hlsl"),
        .model = try asset_manager.loadFile(GltfAsset, "assets/DamagedHelmet.glb"),
        .skybox_image = skybox_image,
        .irradiance_image = irradiance_image,
        .radiance_image = radiance_image,
        .brdf_image = brdf_image,
        .radiance_sampler = radiance_sampler,
        .irradiance_sampler = irradiance_sampler,
    };

    self.inner_atm_mesh.material.uniform.base_color_factor = Vec4.init(
        65.0 / 255.0,
        152.0 / 255.0,
        10.0 / 255.0,
        1.0,
    );
    return self;
}

pub fn deinit(self: *App) void {
    self.engine.device.destroyImage(self.irradiance_image);
    self.engine.device.destroyImage(self.radiance_image);
    self.engine.device.destroyImage(self.brdf_image);
    self.engine.device.destroySampler(self.radiance_sampler);
    self.engine.device.destroySampler(self.irradiance_sampler);
    self.cube_mesh.deinit();
    self.outer_atm_mesh.deinit();
    self.inner_atm_mesh.deinit();
    self.graph.destroy();
    self.asset_manager.deinit();
    self.engine.deinit();
    self.allocator.destroy(self);
}

fn mainPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
    var self: *App = @ptrCast(*App, @alignCast(@alignOf(App), user_data));

    self.camera.update(self.engine, @floatCast(f32, self.delta_time));

    self.sun_angle += self.delta_time * 0.1;
    self.sun_angle = @mod(self.sun_angle, std.math.pi * 2.0);

    var atmosphere = Atmosphere.init(.{
        .camera_pos = self.camera.pos,
        .sun_pos = Vec3.init(
            0.0,
            @floatCast(f32, sin(self.sun_angle)),
            @floatCast(f32, cos(self.sun_angle)),
        ).normalize(),
        .inner_radius = world_inner_radius,
        .outer_radius = world_outer_radius,
    });

    cb.bindPipeline(self.atmosphere_sky_pipeline.pipeline);
    cb.setUniform(0, 0,
        @sizeOf(@TypeOf(self.camera.uniform)),
        &self.camera.uniform);
    cb.setUniform(1, 0,
        @sizeOf(@TypeOf(atmosphere)),
         &atmosphere);
    self.outer_atm_mesh.draw(cb, null, null, null);

    cb.bindPipeline(self.model_pipeline.pipeline);
    cb.setUniform(0, 0,
        @sizeOf(@TypeOf(self.camera.uniform)),
        @ptrCast(*c_void, &self.camera.uniform));

    cb.bindSampler(0, 1, self.irradiance_sampler);
    cb.bindSampler(1, 1, self.radiance_sampler);
    cb.bindImage(2, 1, self.irradiance_image);
    cb.bindImage(3, 1, self.radiance_image);
    cb.bindImage(4, 1, self.brdf_image);

    self.inner_atm_mesh.draw(cb, &Mat4.identity, 2, 3);
    self.model.draw(cb, &Mat4.scaling(Vec3.single(5.0)), 2, 3);
}

pub fn run(self: *App) !void {
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
                .KeyPressed => |keyboard| {
                    if (keyboard.key == .Escape) {
                        self.engine.setCursorEnabled(!self.engine.getCursorEnabled());
                    }
                },
                else => {}
            }
        }

        self.asset_manager.refreshAssets();
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
