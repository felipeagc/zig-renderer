const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
usingnamespace @import("./main.zig");

pub const EngineError = error{InitFail};

pub extern fn glfwGetX11Display() ?*c_void;
pub extern fn glfwGetX11Window(?*c.GLFWwindow) ?*c_void;
pub extern fn glfwGetWin32Window(?*c.GLFWwindow) ?*c_void;

pub const Engine = struct {
    alloc: *Allocator,
    window: ?*c.GLFWwindow = null,
    device: ?*rg.Device = null,
    white_image: ?*rg.Image = null,
    black_image: ?*rg.Image = null,

    fn onResizeGLFW(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
        var self: *Engine = @ptrCast(*Engine, 
            @alignCast(@alignOf(*Engine), c.glfwGetWindowUserPointer(window)));
        std.log.info("window resized", .{});
    }

    fn getWindowInfo(self: *Engine) rg.PlatformWindowInfo {
        var window_info: rg.PlatformWindowInfo = .{.x11 = .{}, .win32 = .{}};

        if (builtin.os.tag == .windows) {
            window_info.win32.window = glfwGetWin32Window(self.window);
        } else {
            window_info.x11.window = glfwGetX11Window(self.window);
            window_info.x11.display = glfwGetX11Display();
        }

        return window_info;
    }

    pub fn init(alloc: *Allocator) !*Engine {
        var self = try alloc.create(Engine);

        if (c.glfwInit() != c.GLFW_TRUE) {
            return error.InitFail;
        }

        var window = c.glfwCreateWindow(800, 600, "Renderer", null, null);
        c.glfwSetWindowUserPointer(window, @ptrCast(*c_void, self));
        _ = c.glfwSetWindowSizeCallback(window, onResizeGLFW);

        var device = rg.deviceCreate();

        var image_info = rg.ImageInfo{
            .width = 1,
            .height = 1,
            .usage = @enumToInt(rg.ImageUsage.Sampled)
                | @enumToInt(rg.ImageUsage.TransferDst),
            .format = .Rgba8Unorm,
            .aspect = @enumToInt(rg.ImageAspect.Color),
        };

        var white_image = rg.imageCreate(device, &image_info);
        var black_image = rg.imageCreate(device, &image_info);

        var white_data = [_]u8{255, 255, 255, 255};
        rg.imageUpload(device, &rg.ImageCopy{
                .image = white_image,
                .mip_level = 0,
                .array_layer = 0,
                .offset = .{.x = 0, .y = 0, .z = 0},
            },
            &rg.Extent3D{.width = 1, .height = 1, .depth = 1},
            @sizeOf(@TypeOf(white_data)),
            &white_data[0]);

        var black_data = [_]u8{0, 0, 0, 255};
        rg.imageUpload(device, &rg.ImageCopy{
                .image = white_image,
                .mip_level = 0,
                .array_layer = 0,
                .offset = .{.x = 0, .y = 0, .z = 0},
            },
            &rg.Extent3D{.width = 1, .height = 1, .depth = 1},
            @sizeOf(@TypeOf(black_data)),
            &black_data[0]);

        self.* = Engine{
            .alloc = alloc,
            .window = window,
            .device = device,
            .white_image = white_image,
            .black_image = black_image,
        };

        return self;
    }

    pub fn deinit(self: *Engine) void {
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();

        rg.imageDestroy(self.device, self.white_image);
        rg.imageDestroy(self.device, self.black_image);
        rg.deviceDestroy(self.device);
        self.alloc.destroy(self);
    }

    pub fn run(self: *Engine) !void {
        while (c.glfwWindowShouldClose(self.window) == 0) {
            c.glfwPollEvents();
        }
    }
};

