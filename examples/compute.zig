usingnamespace @import("renderer");

const ts = tinyshader;

pub const App = @This();

allocator: *Allocator,
device: *rg.Device,
pipeline: *rg.Pipeline,
graph: *rg.Graph,

pub fn init(allocator: *Allocator) !*App {
    var self = try allocator.create(App);
    errdefer allocator.destroy(self);

    var device_info = rg.DeviceInfo{
        .enable_validation = true,
        .window_system = .None,
    };
    var device = rg.Device.create(&device_info) orelse return error.InitFail;

    var spirv = try compileShaderAlloc(
        allocator, "main", @embedFile("../shaders/compute.hlsl"));
    defer allocator.free(spirv);

    var pipeline = rg.extComputePipelineCreateWithShaders(
        device,
        &rg.ExtCompiledShader{
            .code = spirv.ptr,
            .code_size = spirv.len,
            .entry_point = "main",
        })
        orelse return error.ShaderCompilationFailed;

    var graph = rg.Graph.create() orelse return error.InitFail;

    var pass = graph.addPass(.Compute, callback);

    graph.build(device, &rg.GraphInfo{
        .width = 0,
        .height = 0,

        .user_data = @ptrCast(*c_void, self),
    });

    self.* = .{
        .allocator = allocator,
        .device = device,
        .pipeline = pipeline,
        .graph = graph,
    };

    return self;
}

fn callback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
    var self = @ptrCast(*@This(), @alignCast(@alignOf(@This()), user_data));
    cb.bindPipeline(self.pipeline);
    cb.dispatch(1, 1, 1);
}

pub fn deinit(self: *App) void {
    self.graph.destroy();
    self.device.destroyPipeline(self.pipeline);
    self.device.destroy();
    self.allocator.destroy(self);
}

pub fn run(self: *App) !void {
    self.graph.execute();
    self.graph.waitAll();
}

pub fn main() !void {
    const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = try App.init(&gpa.allocator);
    defer app.deinit();

    try app.run();
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
