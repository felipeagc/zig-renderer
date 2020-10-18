usingnamespace @import("./common.zig");
usingnamespace @import("./assets.zig");
usingnamespace @import("./math.zig");
usingnamespace @import("./ktx.zig");
const Engine = @import("./Engine.zig").Engine;

const Self = @This();
pub const ImageAsset = Self;

engine: *Engine,
image: *rg.Image,

pub fn init(engine: *Engine, data: []const u8) anyerror!*Self {
    const allocator = engine.alloc;

    var image: ?*rg.Image = null;

    if (data.len >= ktx1_identifier.len 
        and mem.eql(u8, data[0..ktx1_identifier.len], &ktx1_identifier)) {
        // KTX image

        var ktx = try Ktx.init(allocator, data);
        defer ktx.deinit();

        image = engine.device.createImage(&rg.ImageInfo{
            .width = ktx.texel_width,
            .height = ktx.texel_height,
            .depth = ktx.texel_depth,

            .mip_count = ktx.mip_count,
            .layer_count = ktx.face_count,

            .usage = rg.ImageUsage.Sampled | rg.ImageUsage.TransferDst,
            .aspect = rg.ImageAspect.Color,
            .format = switch (ktx.format) {
                .Rgb8 => rg.Format.Rgb8Unorm,
                .Rgba8 => rg.Format.Rgba8Unorm,
                .Rgba16f => rg.Format.Rgba16Sfloat,
                .Rgba32f => rg.Format.Rgba32Sfloat,
                .Bc7Unorm => rg.Format.Bc7Unorm,
                .Bc7Srgb => rg.Format.Bc7Srgb,
                else => {
                    return error.ImageAssetUnsupportedFormat;
                },
            },
        });

        for (ktx.levels) |level, m| {
            var mip_width = ktx.texel_width / (@as(u32, 1) << @intCast(u5, m));
            var mip_height = ktx.texel_height / (@as(u32, 1) << @intCast(u5, m));

            for (level.layers) |layer, l| {
                for (layer.faces) |face, f| {
                    engine.device.uploadImage(
                        &rg.ImageCopy{
                            .image = image.?,
                            .mip_level = @intCast(u32, m),
                            .array_layer = @intCast(u32, f),
                        }, 
                        &rg.Extent3D{
                            .width = mip_width,
                            .height = mip_height,
                            .depth = ktx.texel_depth,
                        },
                        face.data.len,
                        face.data.ptr,
                    );
                }
            }
        }

    } else {
        return error.ImageAssetUnknownFileType;
    }

    var self = try allocator.create(Self);
    self.* = .{
        .engine = engine,
        .image = image orelse return error.ImageAssetLoadFail,
    };
    return self;
}

pub fn deinit(self_opaque: *c_void) void {
    var self = @ptrCast(*Self, @alignCast(@alignOf(@This()), self_opaque));
    self.engine.device.destroyImage(self.image);
    self.engine.alloc.destroy(self);
}
