const std = @import("std");
const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("tinyshader/tinyshader.h");
    @cInclude("rendergraph/rendergraph.h");
    @cInclude("GLFW/glfw3.h");
});
const mem = std.mem;
const Allocator = std.mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;

const EngineError = error{InitFail};

const Engine = struct {
    alloc: *Allocator,
    window: ?*c.GLFWwindow = null,
    device: ?*c.RgDevice = null,

    fn create(alloc: *Allocator) anyerror!*Engine {
        var self = try alloc.create(Engine);

        if (c.glfwInit() != c.GLFW_TRUE) {
            return error.InitFail;
        }

        var window = c.glfwCreateWindow(800, 600, "Renderer", null, null);

        var device = c.rgDeviceCreate();

        self.* = Engine{
            .alloc = alloc,
            .window = window,
            .device = device,
        };

        return self;
    }

    fn deinit(self: Engine) void {
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();

        c.rgDeviceDestroy(self.device);
        self.alloc.destroy(&self);
    }

    fn run(self: *Engine) anyerror!void {
        while (c.glfwWindowShouldClose(self.window) == 0) {
            c.glfwPollEvents();
        }
    }
};

pub fn main() anyerror!void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
    }

    var engine = try Engine.create(&gpa.allocator);
    defer engine.deinit();

    try engine.run();
}
