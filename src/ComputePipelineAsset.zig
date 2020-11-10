usingnamespace @import("./common.zig");
usingnamespace @import("./assets.zig");
const Engine = @import("./Engine.zig").Engine;

const ts = @import("tinyshader.zig");

const Self = @This();
pub const ComputePipelineAsset = Self;

engine: *Engine,
pipeline: *rg.Pipeline = null,

pub fn init(
    self_opaque: *c_void,
    engine: *Engine,
    data: []const u8,
    path: ?[*:0]const u8,
) anyerror!void {
    var self = @ptrCast(*Self, @alignCast(@alignOf(@This()), self_opaque));

    const allocator = engine.alloc;

    var spirv = try compileShaderAlloc(allocator, "main", .Compute, data);
    defer allocator.free(spirv);

    var shader = rg.ExtCompiledShader{
        .code = spirv.ptr,
        .code_size = spirv.len,
        .entry_point = "main",
    };

    var pipeline = rg.extComputePipelineCreateWithShaders(
        engine.device, &shader) 
        orelse return error.ShaderCompilationFailed;

    self.* = Self{
        .engine = engine,
        .pipeline = pipeline,
    };
}

pub fn deinit(self_opaque: *c_void) void {
    var self = @ptrCast(*Self, @alignCast(@alignOf(@This()), self_opaque));
    self.engine.device.destroyPipeline(self.pipeline);
}

fn compileShaderAlloc(
    alloc: *Allocator,
    entry_point: [*:0]const u8,
    code: []const u8) ![]const u8 {
    var compiler = ts.compilerCreate();
    defer ts.compilerDestroy(compiler);

    var input = ts.CompilerInput{
        .path = null,
        .input = &code[0],
        .input_size = code.len,
        .entry_point = entry_point,
        .stage = .Compute,
    };

    var output: ts.CompilerOutput = undefined;
    defer ts.compilerOutputDestroy(&output);

    ts.compile(compiler, &input, &output);

    if (output.error_ != null) {
        std.debug.print("Tinyshader error:\n{s}\n", .{output.error_});
        return error.ShaderCompilationFailed;
    }

    var code_spv = try alloc.alloc(u8, output.spirv_byte_size);
    mem.copy(u8, code_spv, output.spirv[0..output.spirv_byte_size]);

    return code_spv;
}
