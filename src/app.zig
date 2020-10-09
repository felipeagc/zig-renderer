usingnamespace @import("./asset_manager.zig");
usingnamespace @import("./pipeline_asset.zig");
usingnamespace @import("./engine.zig");
usingnamespace @import("./main.zig");

pub const App = struct {
    allocator: *Allocator,
    engine: *Engine,
    asset_manager: *AssetManager,
    pipeline: *PipelineAsset,
    graph: *rg.Graph,

    fn onResize(user_data: ?*c_void, width: i32, height: i32) void {
        if (user_data == null) return;
        var self: *App = @ptrCast(*App, @alignCast(@alignOf(*App), user_data));
        rg.graphResize(self.graph);

        std.log.info("window resized", .{});
    }

    pub fn init(allocator: *Allocator) !*App {
        var self = try allocator.create(App);

        var engine = try Engine.init(allocator);
        engine.user_data = @ptrCast(*c_void, self);
        engine.on_resize = onResize;

        var asset_manager = try AssetManager.init(engine);

        var pipeline = try asset_manager.load(PipelineAsset, @embedFile("../shaders/shader.hlsl"));

        var graph = rg.graphCreate(engine.device, @ptrCast(*c_void, self), &try engine.getWindowInfo())
            orelse return error.InitFail;

        var depth_info = rg.ResourceInfo{
            .type_ = .DepthStencilAttachment,
            .info = .{
                .image = .{
                    .width = 0,
                    .height = 0,
                    .usage = 0,
                    .aspect = 0,
                    .format = .D24UnormS8Uint
                }
            }
        };
        var depth_res = rg.graphAddResource(graph, &depth_info) orelse return error.InitFail;

        var main_pass = rg.graphAddPass(graph, mainPassCallback) orelse return error.InitFail;
        rg.graphAddPassOutput(main_pass, depth_res);

        rg.graphBuild(graph);

        self.* = .{
            .allocator = allocator,
            .engine = engine,
            .asset_manager = asset_manager,
            .pipeline = pipeline,
            .graph = graph,
        };
        return self;
    }

    fn mainPassCallback(user_data: *c_void, cb: *rg.CmdBuffer) callconv(.C) void {
        var self: *App = @ptrCast(*App, @alignCast(@alignOf(*App), user_data));

    }

    pub fn run(self: *App) !void {
        while (!self.engine.shouldClose()) {
            self.engine.pollEvents();
            rg.graphExecute(self.graph);
        }
    }

    pub fn deinit(self: *App) void {
        rg.graphDestroy(self.graph);
        self.asset_manager.deinit();
        self.engine.deinit();
        self.allocator.destroy(self);
    }
};
