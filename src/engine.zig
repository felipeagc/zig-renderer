pub const rg = @import("./rendergraph.zig");
usingnamespace @import("./main.zig");

pub const EngineError = error{InitFail};

pub extern fn glfwGetX11Display() ?*c_void;
pub extern fn glfwGetX11Window(?*c.GLFWwindow) ?*c_void;
pub extern fn glfwGetWin32Window(?*c.GLFWwindow) ?*c_void;

pub const Engine = struct {
    alloc: *Allocator,
    window: *c.GLFWwindow,
    device: *rg.Device,
    white_image: *rg.Image,
    black_image: *rg.Image,
    user_data: ?*c_void = null,
    on_resize: ?fn(?*c_void, i32, i32) void = null,

    fn onResizeGLFW(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
        var self: *Engine = @ptrCast(*Engine, 
            @alignCast(@alignOf(*Engine), c.glfwGetWindowUserPointer(window)));

        if (self.on_resize) |on_resize| {
            on_resize(self.user_data, @as(i32, width), @as(i32, height));
        }
    }

    pub fn getWindowInfo(self: *Engine) !rg.PlatformWindowInfo {
        var window_info: rg.PlatformWindowInfo = .{.x11 = .{}, .win32 = .{}};

        if (builtin.os.tag == .windows) {
            window_info.win32.window = glfwGetWin32Window(self.window) orelse return error.InitFail;
        } else {
            window_info.x11.window = glfwGetX11Window(self.window) orelse return error.InitFail;
            window_info.x11.display = glfwGetX11Display() orelse return error.InitFail;
        }

        return window_info;
    }

    pub fn init(alloc: *Allocator) !*Engine {
        var self = try alloc.create(Engine);
        errdefer alloc.destroy(self);

        if (c.glfwInit() != c.GLFW_TRUE) {
            return error.InitFail;
        }

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        var window = c.glfwCreateWindow(800, 600, "Renderer", null, null)
            orelse return error.InitFail;
        c.glfwSetWindowUserPointer(window, @ptrCast(*c_void, self));
        _ = c.glfwSetWindowSizeCallback(window, onResizeGLFW);

        var device = rg.deviceCreate() orelse return error.InitFail;

        var image_info = rg.ImageInfo{
            .width = 1,
            .height = 1,
            .usage = @enumToInt(rg.ImageUsage.Sampled)
                | @enumToInt(rg.ImageUsage.TransferDst),
            .format = .Rgba8Unorm,
            .aspect = @enumToInt(rg.ImageAspect.Color),
        };

        var white_image = rg.imageCreate(device, &image_info) orelse return error.InitFail;
        var black_image = rg.imageCreate(device, &image_info) orelse return error.InitFail;

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

    pub fn shouldClose(self: *Engine) bool {
        return c.glfwWindowShouldClose(self.window) != 0;
    }

    pub fn pollEvents(self: *Engine) void {
        c.glfwPollEvents();
    }

    pub fn getTime(self: *Engine) f64 {
        return c.glfwGetTime();
    }

    pub fn getWindowSize(self: *Engine) struct{width: i32, height: i32} {
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetFramebufferSize(self.window, &width, &height);
        return .{.width = @as(i32, width), .height = @as(i32, height)};
    }
};

