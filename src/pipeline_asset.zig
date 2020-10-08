const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
usingnamespace @import("./asset_manager.zig");
usingnamespace @import("./engine.zig");
usingnamespace @import("./main.zig");

pub const PipelineAsset = extern struct {
    engine: *Engine,
    pipeline: ?*c.RgPipeline = null,

    pub fn init(engine: *Engine, data: []const u8) anyerror!*PipelineAsset {
        const alloc = engine.alloc;
        var self = try alloc.create(PipelineAsset);

        self.* = PipelineAsset{
            .engine = engine,
        };

        var vert_spirv = try compileShaderAlloc(
            engine.alloc,
            "vertex",
            c.enum_TsShaderStage.TS_SHADER_STAGE_VERTEX,
            data,
        );
        defer alloc.free(vert_spirv);
        
        var frag_spirv = try compileShaderAlloc(
            engine.alloc,
            "pixel",
            c.enum_TsShaderStage.TS_SHADER_STAGE_FRAGMENT,
            data,
        );
        defer alloc.free(frag_spirv);

        return self;
    }

    pub fn deinit(self_opaque: OpaqueAssetPtr) void {
        var self = @ptrCast(*PipelineAsset, self_opaque);
        const alloc = self.engine.alloc;
        alloc.destroy(self);
    }

    pub fn hash(self: *PipelineAsset) AssetHash {
        return [_]u8{0} ** 32;
    }
};

pub const ShaderError = error{ShaderCompilationFailed};

fn compileShaderAlloc(
    alloc: *Allocator,
    entry_point: [*:0]const u8,
    stage: c.TsShaderStage,
    code: []const u8) ![]const u8 {
    var compiler = c.tsCompilerCreate();
    defer c.tsCompilerDestroy(compiler);

    var input = c.TsCompilerInput{
        .path = null,
        .input = &code[0],
        .input_size = code.len,
        .entry_point = entry_point,
        .stage = stage,
    };

    var output: c.TsCompilerOutput = undefined;

    c.tsCompile(compiler, &input, &output);

    if (output.@"error" != null) {
        std.debug.print("Tinyshader error: {}\n", .{output.@"error"});
        c.tsCompilerOutputDestroy(&output);
        return error.ShaderCompilationFailed;
    }

    var code_spv = try alloc.alloc(u8, output.spirv_byte_size);
    mem.copy(u8, code_spv, output.spirv[0..output.spirv_byte_size]);

    c.tsCompilerOutputDestroy(&output);
    return code_spv;
}
