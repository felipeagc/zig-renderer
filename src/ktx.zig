const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const max = std.math.max;

pub const ktx1_identifier = [12]u8{
    '«', 'K', 'T', 'X', ' ', '1', '1', '»', '\r', '\n', '\x1A', '\n',
};

const Ktx1Header = extern struct {
    identifier: [12]u8,
    endianness: u32,
    gl_type: u32,
    gl_type_size: u32,
    gl_format: u32,
    gl_internal_format: Format, // This is the format we care about
    gl_base_internal_format: u32,
    pixel_width: u32,
    pixel_height: u32,
    pixel_depth: u32,
    number_of_array_elements: u32,
    number_of_faces: u32,
    number_of_mipmap_levels: u32,
    bytes_of_key_value_data: u32,
};

pub const Face = struct {
    data: []const u8,
};

pub const Layer = struct {
    faces: []Face,
};

pub const Level = struct {
    layers: []Layer,
};

pub const Format = extern enum(u32) {
    Undefined = 0,
    R8 = 0x8229,
    R8Snorm = 0x8F94,
    R16 = 0x822A,
    R16Snorm = 0x8F98,
    Rg8 = 0x822B,
    Rg8Snorm = 0x8F95,
    Rg16 = 0x822C,
    Rg16Snorm = 0x8F99,
    R3G3B2 = 0x2A10,
    Rgb4 = 0x804F,
    Rgb5 = 0x8050,
    Rgb565 = 0x8D62,
    Rgb8 = 0x8051,
    Rgb8Snorm = 0x8F96,
    Rgb10 = 0x8052,
    Rgb12 = 0x8053,
    Rgb16 = 0x8054,
    Rgb16Snorm = 0x8F9A,
    Rgba2 = 0x8055,
    Rgba4 = 0x8056,
    Rgb5A1 = 0x8057,
    Rgba8 = 0x8058,
    Rgba8Snorm = 0x8F97,
    Rgb10A2 = 0x8059,
    Rgb10A2ui = 0x906F,
    Rgba12 = 0x805A,
    Rgba16 = 0x805B,
    Rgba16Snorm = 0x8F9B,
    Srgb8 = 0x8C41,
    Srgb8Alpha8 = 0x8C43,
    R16f = 0x822D,
    Rg16f = 0x822F,
    Rgb16f = 0x881B,
    Rgba16f = 0x881A,
    R32f = 0x822E,
    Rg32f = 0x8230,
    Rgb32f = 0x8815,
    Rgba32f = 0x8814,
    R11fG11fB10f = 0x8C3A,
    Rgb9E5 = 0x8C3D,
    R8i = 0x8231,
    R8ui = 0x8232,
    R16i = 0x8233,
    R16ui = 0x8234,
    R32i = 0x8235,
    R32ui = 0x8236,
    Rg8i = 0x8237,
    Rg8ui = 0x8238,
    Rg16i = 0x8239,
    Rg16ui = 0x823A,
    Rg32i = 0x823B,
    Rg32ui = 0x823C,
    Rgb8i = 0x8D8F,
    Rgb8ui = 0x8D7D,
    Rgb16i = 0x8D89,
    Rgb16ui = 0x8D77,
    Rgb32i = 0x8D83,
    Rgb32ui = 0x8D71,
    Rgba8i = 0x8D8E,
    Rgba8ui = 0x8D7C,
    Rgba16i = 0x8D88,
    Rgba16ui = 0x8D76,
    Rgba32i = 0x8D82,

    Bc7Unorm = 0x8E8C,
    Bc7Srgb = 0x8E8D,
};

fn blockSize(format: Format) !u32 {
    switch (format) {
        .Rgb8 => return 3,
        .Rgba8 => return 4,
        .Rgba16f => return 8,
        .Rgba32f => return 16,
        .Bc7Unorm => return 16,
        .Bc7Srgb => return 16,
        else => return error.KtxInvalidFormat,
    }
}

pub const Ktx = struct {
    allocator: *Allocator,
    texel_width: u32,
    texel_height: u32,
    texel_depth: u32,
    mip_count: u32,
    face_count: u32,
    layer_count: u32,
    format: Format,
    levels: []Level,

    const Self = @This();

    pub fn init(allocator: *Allocator, data: []const u8) !Ktx {
        if (data.len < @sizeOf(Ktx1Header)) return error.KtxLoadError;

        var offset: usize = 0;

        var header: Ktx1Header = undefined;
        mem.copy(u8,
            @ptrCast([*]u8, &header)[0..@sizeOf(Ktx1Header)],
            data[offset..offset+@sizeOf(Ktx1Header)]);
        offset += @sizeOf(Ktx1Header);

        if (!mem.eql(u8, &header.identifier, &ktx1_identifier)) return error.KtxLoadError;

        if (header.endianness != 0x04030201) return error.KtxBigEndianNotSupported;

        offset += header.bytes_of_key_value_data;

        var block_size = try blockSize(header.gl_internal_format);

        var levels: []Level = try allocator.alloc(Level, header.number_of_mipmap_levels);
        errdefer allocator.free(levels);

        var texel_width: u32 = header.pixel_width;
        var texel_height: u32 = header.pixel_height;
        var texel_depth: u32 = max(1, header.pixel_depth);

        switch (header.gl_internal_format) {
            .Bc7Unorm => {
                texel_width >>= 2;
                texel_height >>= 2;
            },
            .Bc7Srgb => {
                texel_width >>= 2;
                texel_height >>= 2;
            },
            else => {},
        }

        // Read mip maps
        var m: u5 = 0;
        while (m < max(1, header.number_of_mipmap_levels)) : (m += 1) {
            var mip_width = texel_width / (@as(u32, 1) << m);
            var mip_height = texel_height / (@as(u32, 1) << m);

            var image_size: u32 = undefined;
            mem.copy(u8,
                @ptrCast([*]u8, &image_size)[0..@sizeOf(u32)],
                data[offset..offset+@sizeOf(u32)]);
            offset += @sizeOf(u32);

            levels[m].layers = try allocator.alloc(Layer,
                max(1, header.number_of_array_elements));

            // Read layers
            var l: usize = 0;
            while (l < max(1, header.number_of_array_elements)) : (l += 1) {
                levels[m].layers[l].faces = 
                    try allocator.alloc(Face, header.number_of_faces);

                // Read faces
                var f: usize = 0;
                while (f < header.number_of_faces) : (f += 1) {
                    var data_size = 
                        mip_width * mip_height * texel_depth * block_size;
                    var face_data = try allocator.alloc(u8, data_size);
                    mem.copy(u8, face_data, data[offset..offset+data_size]);
                    levels[m].layers[l].faces[f].data = face_data;

                    offset += data_size;
                    offset = mem.alignForward(offset, 4);
                }
            }
            offset = mem.alignForward(offset, 4);
        }

        if (offset != data.len) return error.KtxLoadError;

        return Ktx{
            .allocator = allocator,
            .levels = levels,
            .format = header.gl_internal_format,
            .texel_width = texel_width,
            .texel_height = texel_height,
            .texel_depth = texel_depth,
            .mip_count = header.number_of_mipmap_levels,
            .layer_count = max(1, header.number_of_array_elements),
            .face_count = header.number_of_faces,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.levels) |level| {
            for (level.layers) |layer| {
                for (layer.faces) |face| {
                    self.allocator.free(face.data);
                }
                self.allocator.free(layer.faces);
            }
            self.allocator.free(level.layers);
        }
        self.allocator.free(self.levels);
    }
};
