const std = @import("std");
const Allocator = std.mem.Allocator;
usingnamespace @import("./main.zig");

pub const EngineError = error{InitFail};

pub const Engine = struct {
    alloc: *Allocator,
    window: ?*c.GLFWwindow = null,
    device: ?*c.RgDevice = null,

    pub fn init(alloc: *Allocator) !*Engine {
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

    pub fn deinit(self: *Engine) void {
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();

        c.rgDeviceDestroy(self.device);
        self.alloc.destroy(self);
    }

    pub fn run(self: *Engine) !void {
        while (c.glfwWindowShouldClose(self.window) == 0) {
            c.glfwPollEvents();
        }
    }
};

