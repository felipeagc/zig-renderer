usingnamespace @import("renderer");

const ts = tinyshader;

pub const App = @This();

allocator: *Allocator,
device: *rg.Device,
cmd_pool: *rg.CmdPool,
pipeline: *rg.Pipeline,
graph: *rg.Graph,
main_pass: rg.PassRef,
buffer: *rg.Buffer,
array: *[32_000_000]f32,

pub fn init(allocator: *Allocator) !*App {
    var self = try allocator.create(App);
    errdefer allocator.destroy(self);

    var device_info = rg.DeviceInfo{
        .enable_validation = true,
        .window_system = .None,
    };
    var device = rg.Device.create(&device_info) orelse return error.InitFail;

    var cmd_pool = device.createCmdPool() orelse return error.InitFail;

    var array: *[32_000_000]f32 = try allocator.create([32_000_000]f32);
    for (array) |*elem| {
        elem.* = 1.0;
    }

    var buffer = device.createBuffer(&rg.BufferInfo{
        .size = @sizeOf(@TypeOf(array.*)),
        .usage = rg.BufferUsage.Storage | rg.BufferUsage.TransferSrc | rg.BufferUsage.TransferDst,
        .memory = .Host,
    }) orelse return error.InitFail;

    device.uploadBuffer(cmd_pool, buffer, 0, @sizeOf(@TypeOf(array.*)), array);

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

    var main_pass = graph.addPass(.Compute);

    graph.build(
        device,
        cmd_pool,
        &rg.GraphInfo{
            .width = 0,
            .height = 0,
            .preferred_swapchain_format = .Undefined,

            .user_data = @ptrCast(*c_void, self),
        });

    self.* = .{
        .allocator = allocator,
        .device = device,
        .cmd_pool = cmd_pool,
        .pipeline = pipeline,
        .graph = graph,
        .main_pass = main_pass,
        .buffer = buffer,
        .array = array,
    };

    return self;
}

pub fn deinit(self: *App) void {
    self.allocator.destroy(self.array);
    self.device.destroyBuffer(self.buffer);
    self.graph.destroy();
    self.device.destroyPipeline(self.pipeline);
    self.device.destroyCmdPool(self.cmd_pool);
    self.device.destroy();
    self.allocator.destroy(self);
}

pub fn run(self: *App) !void {
    {
        var cb = self.graph.beginPass(self.main_pass);
        defer self.graph.endPass(self.main_pass);

        cb.bindPipeline(self.pipeline);
        cb.bindStorageBuffer(0, 0, self.buffer, 0, 0);
        cb.dispatch(256, 1, 1);
    }

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
