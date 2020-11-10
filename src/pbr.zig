usingnamespace @import("./common.zig");
usingnamespace @import("./math.zig");
const Engine = @import("./Engine.zig").Engine;

pub const Vertex = extern struct {
    pos: Vec3,
    normal: Vec3 = Vec3.init(0.0, 0.0, 0.0),
    tangent: Vec4 = Vec4.init(0.0, 0.0, 0.0, 1.0),
    uv: Vec2 = Vec2.init(0.0, 0.0),
};

pub const MaterialUniform = extern struct {
    base_color_factor: Vec4 = Vec4.init(1.0, 1.0, 1.0, 1.0),
    emissive_factor: Vec4 = Vec4.init(1.0, 1.0, 1.0, 1.0),
    metallic: f32 = 1.0,
    roughness: f32 = 1.0,
    is_normal_mapped: u32 = 0,
};

pub const Material = struct {
    uniform: MaterialUniform,

    albedo_image: *rg.Image,
    albedo_sampler: *rg.Sampler,

    normal_image: *rg.Image,
    normal_sampler: *rg.Sampler,

    metallic_roughness_image: *rg.Image,
    metallic_roughness_sampler: *rg.Sampler,

    occlusion_image: *rg.Image,
    occlusion_sampler: *rg.Sampler,

    emissive_image: *rg.Image,
    emissive_sampler: *rg.Sampler,

    pub fn default(engine: *Engine) Material {
        return Material{
            .uniform = .{},

            .albedo_image = engine.white_image,
            .albedo_sampler = engine.default_sampler,

            .normal_image = engine.white_image,
            .normal_sampler = engine.default_sampler,

            .metallic_roughness_image = engine.white_image,
            .metallic_roughness_sampler = engine.default_sampler,

            .occlusion_image = engine.white_image,
            .occlusion_sampler = engine.default_sampler,

            .emissive_image = engine.black_image,
            .emissive_sampler = engine.default_sampler,
        };
    }

    pub fn bind(self: *Material, cb: *rg.CmdBuffer, material_set: u32) void {
        cb.setUniform(0, material_set,
            @sizeOf(@TypeOf(self.uniform)), @ptrCast(*c_void, &self.uniform));
        cb.bindSampler(1, material_set, self.albedo_sampler);
        cb.bindImage(2, material_set, self.albedo_image);
        cb.bindImage(3, material_set, self.normal_image);
        cb.bindImage(4, material_set, self.metallic_roughness_image);
        cb.bindImage(5, material_set, self.occlusion_image);
        cb.bindImage(6, material_set, self.emissive_image);
    }
};
