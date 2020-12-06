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
    entry_point: []const u8,
    code: []const u8,
) ![]const u8 {
    var options = ts.CompilerOptions.create();
    options.setEntryPoint(entry_point);
    options.setStage(.Compute);
    options.setSource(code, null);
    defer options.destroy();

    var output = options.compile();
    defer output.destroy();

    if (output.getErrors()) |errors| {
        std.debug.print("Tinyshader error:\n{s}\n", .{errors});
        return error.ShaderCompilationFailed;
    }

    var spirv = output.getSpirv().?;
    return try alloc.dupe(u8, spirv);
}
