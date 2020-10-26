const std = @import("std");
const Allocator = std.mem.Allocator;

extern fn ZSTD_isError(code: usize) u32;

extern fn ZSTD_decompress(
    dst: *c_void,
    dst_capacity: usize,
    src: *const c_void,
    compressed_size: usize,
) usize;


const ZSTD_CONTENTSIZE_UNKNOWN = std.math.maxInt(u64);
const ZSTD_CONTENTSIZE_ERROR = std.math.maxInt(u64) - 1;

extern fn ZSTD_getFrameContentSize(
    src: *const c_void,
    src_size: usize,
) u64;

pub fn decompressAlloc(allocator: *Allocator, input: []const u8) ![]u8 {
    var decompressed_size = ZSTD_getFrameContentSize(input.ptr, input.len);
    if (decompressed_size == ZSTD_CONTENTSIZE_UNKNOWN) {
        return error.ZstdContentSizeUnknown;
    }
    if (decompressed_size == ZSTD_CONTENTSIZE_ERROR) {
        return error.ZstdContentSizeError;
    }

    var data: []u8 = try allocator.alloc(u8, decompressed_size);
    var result = ZSTD_decompress(data.ptr, data.len, input.ptr, input.len);
    if (ZSTD_isError(result) != 0) {
        return error.ZstdDecompressionError;
    }

    return data;
}
