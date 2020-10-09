const std = @import("std");
pub const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("tinyshader.h");
    @cInclude("rendergraph.h");
    @cInclude("rendergraph_ext.h");
    @cInclude("GLFW/glfw3.h");
});
const Allocator = std.mem.Allocator;
const mem = std.mem;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
usingnamespace @import("./asset_manager.zig");
usingnamespace @import("./pipeline_asset.zig");
usingnamespace @import("./engine.zig");

pub fn main() !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
    }

    var engine = try Engine.init(&gpa.allocator);
    defer engine.deinit();

    var asset_manager = try AssetManager.init(engine);
    defer asset_manager.deinit();

    var asset = try asset_manager.load(PipelineAsset, @embedFile("../shaders/shader.hlsl"));

    try engine.run();
}
