usingnamespace @import("./common.zig");
const options = @import("./options.zig");
const ImguiImpl = @import("./imgui_impl.zig").ImguiImpl;

const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cInclude("GLFW/glfw3.h");
});

pub const Engine = @This();

extern fn glfwGetX11Display() ?*c_void;
extern fn glfwGetX11Window(?*c.GLFWwindow) ?*c_void;
extern fn glfwGetWin32Window(?*c.GLFWwindow) ?*c_void;

extern fn glfwGetWaylandDisplay() ?*c_void;
extern fn glfwGetWaylandWindow(?*c.GLFWwindow) ?*c_void;

alloc: *Allocator,
window: *c.GLFWwindow,
device: *rg.Device,
white_image: *rg.Image,
black_image: *rg.Image,
default_sampler: *rg.Sampler,
main_cmd_pool: *rg.CmdPool,
imgui_impl: ?ImguiImpl,
event_queue: EventQueue = .{},

pub fn getWindowInfo(self: *Engine) !rg.PlatformWindowInfo {
    var window_info: rg.PlatformWindowInfo = .{.x11 = .{}, .win32 = .{}, .wl = .{}};

    if (builtin.os.tag == .windows) {
        window_info.win32.window = glfwGetWin32Window(self.window) orelse return error.InitFail;
    } else {
        if (options.use_wayland) {
            window_info.wl.window = glfwGetWaylandWindow(self.window) orelse return error.InitFail;
            window_info.wl.display = glfwGetWaylandDisplay() orelse return error.InitFail;
        } else {
            window_info.x11.window = glfwGetX11Window(self.window) orelse return error.InitFail;
            window_info.x11.display = glfwGetX11Display() orelse return error.InitFail;
        }
    }

    return window_info;
}

pub fn init(alloc: *Allocator) !*Engine {
    var self = try alloc.create(Engine);
    errdefer alloc.destroy(self);

    if (c.glfwInit() != c.GLFW_TRUE) return error.InitFail;

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    var window = c.glfwCreateWindow(800, 600, "Renderer", null, null)
        orelse return error.InitFail;
    c.glfwSetWindowUserPointer(window, @ptrCast(*c_void, self));
    _ = c.glfwSetWindowSizeCallback(window, windowSizeCallbackGLFW);
    _ = c.glfwSetWindowCloseCallback(window, windowCloseCallbackGLFW);
    _ = c.glfwSetWindowRefreshCallback(window, windowRefreshCallbackGLFW);
    _ = c.glfwSetWindowFocusCallback(window, windowFocusCallbackGLFW);
    _ = c.glfwSetWindowIconifyCallback(window, windowIconifyCallbackGLFW);
    _ = c.glfwSetFramebufferSizeCallback(window, framebufferSizeCallbackGLFW);
    _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallbackGLFW);
    _ = c.glfwSetCursorPosCallback(window, cursorPosCallbackGLFW);
    _ = c.glfwSetCursorEnterCallback(window, cursorEnterCallbackGLFW);
    _ = c.glfwSetScrollCallback(window, scrollCallbackGLFW);
    _ = c.glfwSetKeyCallback(window, keyCallbackGLFW);
    _ = c.glfwSetCharCallback(window, charCallbackGLFW);
    _ = c.glfwSetWindowMaximizeCallback(window, windowMaximizeCallbackGLFW);
    _ = c.glfwSetWindowContentScaleCallback(window, windowContentScaleCallbackGLFW);

    var device_info = rg.DeviceInfo{
        .enable_validation = true,
        .window_system =
            if (builtin.os.tag == .windows) .Win32
            else if (options.use_wayland) .Wayland
            else .X11,
    };
    var device = rg.Device.create(&device_info) orelse return error.InitFail;

    var main_cmd_pool = device.createCmdPool() orelse return error.GpuObjectCreateError;

    var image_info = rg.ImageInfo{
        .width = 1,
        .height = 1,
        .usage = rg.ImageUsage.Sampled | rg.ImageUsage.TransferDst,
        .format = .Rgba8Unorm,
        .aspect = rg.ImageAspect.Color,
    };

    var white_image = device.createImage(&image_info) orelse return error.GpuObjectCreateError;
    var black_image = device.createImage(&image_info) orelse return error.GpuObjectCreateError;

    device.setObjectName(.Image, white_image, "Engine: white image");
    device.setObjectName(.Image, black_image, "Engine: black image");

    var white_data = [_]u8{255, 255, 255, 255};
    device.uploadImage(
        main_cmd_pool,
        &rg.ImageCopy{
            .image = white_image,
            .mip_level = 0,
            .array_layer = 0,
            .offset = .{.x = 0, .y = 0, .z = 0},
        },
        &rg.Extent3D{.width = 1, .height = 1, .depth = 1},
        @sizeOf(@TypeOf(white_data)),
        &white_data[0]);

    var black_data = [_]u8{0, 0, 0, 255};
    device.uploadImage(
        main_cmd_pool,
        &rg.ImageCopy{
            .image = black_image,
            .mip_level = 0,
            .array_layer = 0,
            .offset = .{.x = 0, .y = 0, .z = 0},
        },
        &rg.Extent3D{.width = 1, .height = 1, .depth = 1},
        @sizeOf(@TypeOf(black_data)),
        &black_data[0]);

    var default_sampler = device.createSampler(
        &rg.SamplerInfo{
            .anisotropy = true,
            .max_anisotropy = 16.0,
            .min_filter = .Linear,
            .mag_filter = .Linear,
            .address_mode = .Repeat,
            .border_color = .FloatOpaqueWhite,
        }
    ) orelse return error.GpuObjectCreateError;

    self.* = Engine{
        .alloc = alloc,
        .window = window,
        .device = device,
        .white_image = white_image,
        .black_image = black_image,
        .default_sampler = default_sampler,
        .main_cmd_pool = main_cmd_pool,
        .imgui_impl = null,
    };

    self.imgui_impl = try ImguiImpl.init(self);

    return self;
}

pub fn deinit(self: *Engine) void {
    if (self.imgui_impl) |*imgui_impl| {
        imgui_impl.deinit();
    }

    self.device.destroyImage(self.white_image);
    self.device.destroyImage(self.black_image);
    self.device.destroySampler(self.default_sampler);
    self.device.destroyCmdPool(self.main_cmd_pool);
    self.device.destroy();

    c.glfwDestroyWindow(self.window);
    c.glfwTerminate();

    self.alloc.destroy(self);
}

pub fn shouldClose(self: *Engine) bool {
    return c.glfwWindowShouldClose(self.window) != 0;
}

pub fn pollEvents(self: *Engine) void {
    c.glfwPollEvents();
}

pub fn nextEvent(self: *Engine) ?Event {
    var event: Event = Event.None;

    if (self.event_queue.head != self.event_queue.tail) {
        event = self.event_queue.events[self.event_queue.tail];
        self.event_queue.tail = (self.event_queue.tail + 1) % EventQueue.capacity;
    }


    if (event != .None) {
        if (self.imgui_impl) |*imgui_impl| {
            imgui_impl.handleEvent(&event);
        }
        return event; 
    } else {
        return null;
    }
}

pub fn getTime(self: *Engine) f64 {
    return c.glfwGetTime();
}

pub fn getWindowSize(self: *Engine) struct{width: u32, height: u32} {
    var width: c_int = undefined;
    var height: c_int = undefined;
    c.glfwGetFramebufferSize(self.window, &width, &height);
    return .{.width = @intCast(u32, width), .height = @intCast(u32, height)};
}

pub fn setCursorEnabled(self: *Engine, enabled: bool) void {
    var mode: i32 = if (enabled) c.GLFW_CURSOR_NORMAL else c.GLFW_CURSOR_DISABLED;
    c.glfwSetInputMode(self.window, c.GLFW_CURSOR, mode);
}

pub fn getCursorEnabled(self: *Engine) bool {
    var mode = c.glfwGetInputMode(self.window, c.GLFW_CURSOR);
    return mode == c.GLFW_CURSOR_NORMAL;
}

pub fn getCursorPos(self: *Engine) struct{x: f64, y: f64} {
    var xpos: f64 = undefined;
    var ypos: f64 = undefined;
    c.glfwGetCursorPos(self.window, &xpos, &ypos);
    return .{.x = xpos, .y = ypos};
}

pub fn setCursorPos(self: *Engine, x: i32, y: i32) void {
    c.glfwSetCursorPos(self.window, @intToFloat(f64, x), @intToFloat(f64, y));
}

pub fn getKeyState(self: *Engine, key: Key) bool {
    var state = c.glfwGetKey(self.window, @enumToInt(key));
    switch (state) {
        c.GLFW_PRESS => return true,
        c.GLFW_REPEAT => return true,
        else => return false,
    }
}

pub fn getButtonState(self: *Engine, button: Button) bool {
    var state = c.glfwGetMouseButton(self.window, @enumToInt(button));
    switch (state) {
        c.GLFW_PRESS => return true,
        c.GLFW_REPEAT => return true,
        else => return false,
    }
}

pub const Action = enum(i32) {
    Release = 0,
    Press = 1,
    Repeat = 2,
};

pub const Mod = struct {
    pub const Shift = 0x0001;
    pub const Control = 0x0002;
    pub const Alt = 0x0004;
    pub const Super = 0x0008;
    pub const CapsLock = 0x0010;
    pub const NumLock = 0x0020;
};

pub const Button = enum(i32) {
    Left = 0,
    Right = 1,
    Middle = 2,
    Button4 = 3,
    Button5 = 4,
    Button6 = 5,
    Button7 = 6,
    Button8 = 7,
};

pub const Key = enum(i32) {
    Space        = 32,
    Apostrophe   = 39,
    Comma        = 44, 
    Minus        = 45,
    Period       = 46,
    Slash        = 47,
    Number0      = 48,
    Number1      = 49,
    Number2      = 50,
    Number3      = 51,
    Number4      = 52,
    Number5      = 53,
    Number6      = 54,
    Number7      = 55,
    Number8      = 56,
    Number9      = 57,
    Semicolon    = 59,
    Equal        = 61,
    A            = 65,
    B            = 66,
    C            = 67,
    D            = 68,
    E            = 69,
    F            = 70,
    G            = 71,
    H            = 72,
    I            = 73,
    J            = 74,
    K            = 75,
    L            = 76,
    M            = 77,
    N            = 78,
    O            = 79,
    P            = 80,
    Q            = 81,
    R            = 82,
    S            = 83,
    T            = 84,
    U            = 85,
    V            = 86,
    W            = 87,
    X            = 88,
    Y            = 89,
    Z            = 90,
    LeftBracket  = 91, 
    Backslash    = 92,
    RightBracket = 93,
    GraveAccent  = 96,
    World1       = 161,
    World2       = 162,

    Escape       = 256,
    Enter        = 257,
    Tab          = 258,
    Backspace    = 259,
    Insert       = 260,
    Delete       = 261,
    Right        = 262,
    Left         = 263,
    Down         = 264,
    Up           = 265,
    PageUp       = 266,
    PageDown     = 267,
    Home         = 268,
    End          = 269,
    CapsLock     = 280,
    ScrollLock   = 281,
    NumLock      = 282,
    PrintScreen  = 283,
    Pause        = 284,
    F1           = 290,
    F2           = 291,
    F3           = 292,
    F4           = 293,
    F5           = 294,
    F6           = 295,
    F7           = 296,
    F8           = 297,
    F9           = 298,
    F10          = 299,
    F11          = 300,
    F12          = 301,
    F13          = 302,
    F14          = 303,
    F15          = 304,
    F16          = 305,
    F17          = 306,
    F18          = 307,
    F19          = 308,
    F20          = 309,
    F21          = 310,
    F22          = 311,
    F23          = 312,
    F24          = 313,
    F25          = 314,
    Kp0          = 320,
    Kp1          = 321,
    Kp2          = 322,
    Kp3          = 323,
    Kp4          = 324,
    Kp5          = 325,
    Kp6          = 326,
    Kp7          = 327,
    Kp8          = 328,
    Kp9          = 329,
    KpDecimal    = 330,
    KpDivide     = 331,
    KpMultiply   = 332,
    KpSubtract   = 333,
    KpAdd        = 334,
    KpEnter      = 335,
    KpEqual      = 336,
    LeftShift    = 340,
    LeftControl  = 341,
    LeftAlt      = 342,
    LeftSuper    = 343,
    RightShift   = 344,
    RightControl = 345,
    RightAlt     = 346,
    RightSuper   = 347,
    Menu         = 348,
};

const EventQueue = struct {
    const capacity = 1024;

    events: [capacity]Event = undefined,
    head: usize = 0,
    tail: usize = 0,
};

pub const EventType = enum {
    None,
    WindowMoved,
    WindowResized,
    WindowClosed,
    WindowRefresh,
    WindowFocused,
    WindowDefocused,
    WindowIconified,
    WindowUniconified,
    FramebufferResized,
    ButtonPressed,
    ButtonReleased,
    CursorMoved,
    CursorEntered,
    CursorLeft,
    Scrolled,
    KeyPressed,
    KeyRepeated,
    KeyReleased,
    CodepointInput,
    // MonitorConnected,
    // MonitorDisconnected,

    // FileDropped,

    // JoystickConnected,
    // JoystickDisconnected,

    WindowMaximized,
    WindowUnmaximized,
    WindowScaleChanged,
};

pub const Event = union(EventType) {
    None: void,
    WindowMoved: struct {
        window: ?*c.GLFWwindow,
        x: i32,
        y: i32,
    },
    WindowResized: struct {
        window: ?*c.GLFWwindow,
        width: i32,
        height: i32,
    },
    WindowClosed: struct {window: ?*c.GLFWwindow},
    WindowRefresh: struct {window: ?*c.GLFWwindow},
    WindowFocused: struct {window: ?*c.GLFWwindow},
    WindowDefocused: struct {window: ?*c.GLFWwindow},
    WindowIconified: struct {window: ?*c.GLFWwindow},
    WindowUniconified: struct {window: ?*c.GLFWwindow},
    FramebufferResized: struct {
        window: ?*c.GLFWwindow,
        width: i32,
        height: i32,
    },
    ButtonPressed: struct {
        window: ?*c.GLFWwindow,
        button: Button,
        mods: u32,
    },
    ButtonReleased: struct {
        window: ?*c.GLFWwindow,
        button: Button,
        mods: u32,
    },
    CursorMoved: struct {
        window: ?*c.GLFWwindow,
        x: i32,
        y: i32,
    },
    CursorEntered: struct {window: ?*c.GLFWwindow},
    CursorLeft: struct {window: ?*c.GLFWwindow},
    Scrolled: struct {
        window: ?*c.GLFWwindow,
        x: f64,
        y: f64,
    },
    KeyPressed: struct {
        window: ?*c.GLFWwindow,
        key: Key,
        scancode: i32,
        mods: u32,
    },
    KeyReleased: struct {
        window: ?*c.GLFWwindow,
        key: Key,
        scancode: i32,
        mods: u32,
    },
    KeyRepeated: struct {
        window: ?*c.GLFWwindow,
        key: Key,
        scancode: i32,
        mods: u32,
    },
    CodepointInput: struct {
        window: ?*c.GLFWwindow,
        codepoint: u32,
    },
    WindowMaximized: struct {window: ?*c.GLFWwindow},
    WindowUnmaximized: struct {window: ?*c.GLFWwindow},
    WindowScaleChanged: struct {
        window: ?*c.GLFWwindow,
        x: f32,
        y: f32,
    },
};

fn newEvent(engine: *Engine) *Event {
    var event: *Event = &engine.event_queue.events[engine.event_queue.head];
    engine.event_queue.head = (engine.event_queue.head + 1) % EventQueue.capacity;
    assert(engine.event_queue.head != engine.event_queue.tail);
    event.* = Event.None;
    return event;
}

fn windowPosCallbackGLFW(window: ?*c.GLFWwindow, x: c_int, y: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .WindowMoved = .{
            .window = window,
            .x = x,
            .y = y,
        }
    };
}

fn windowSizeCallbackGLFW(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .WindowResized = .{
            .window = window,
            .width = width,
            .height = height,
        }
    };
}

fn windowCloseCallbackGLFW(window: ?*c.GLFWwindow) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .WindowClosed = .{.window = window,}
    };
}

fn windowRefreshCallbackGLFW(window: ?*c.GLFWwindow) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .WindowRefresh = .{.window = window,}
    };
}

fn windowFocusCallbackGLFW(window: ?*c.GLFWwindow, focused: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = if (focused != 0) Event{.WindowFocused = .{.window = window}}
              else Event{.WindowDefocused = .{.window = window}};
}

fn windowIconifyCallbackGLFW(window: ?*c.GLFWwindow, iconified: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = if (iconified != 0) Event{.WindowIconified = .{.window = window}}
              else Event{.WindowUniconified = .{.window = window}};
}

fn framebufferSizeCallbackGLFW(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .FramebufferResized = .{
            .window = window,
            .width = width,
            .height = height,
        }
    };
}

fn mouseButtonCallbackGLFW(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    if (action == c.GLFW_PRESS) {
        var event = self.newEvent();
        event.* = Event{
            .ButtonPressed = .{
                .window = window,
                .button = @intToEnum(Button, button),
                .mods = @intCast(u32, mods),
            }
        };
    } else if (action == c.GLFW_RELEASE) {
        var event = self.newEvent();
        event.* = Event{
            .ButtonReleased = .{
                .window = window,
                .button = @intToEnum(Button, button),
                .mods = @intCast(u32, mods),
            }
        };
    }
}

fn cursorPosCallbackGLFW(window: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .CursorMoved = .{
            .window = window,
            .x = @floatToInt(i32, x),
            .y = @floatToInt(i32, y),
        }
    };
}

fn cursorEnterCallbackGLFW(window: ?*c.GLFWwindow, entered: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    if (entered != 0) {
        var event = self.newEvent();
        event.* = Event{.CursorEntered = .{.window = window}};
    } else {
        var event = self.newEvent();
        event.* = Event{.CursorLeft = .{.window = window}};
    }
}

fn scrollCallbackGLFW(window: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{.Scrolled = .{.window = window, .x = x, .y = y}};
}

fn keyCallbackGLFW(
    window: ?*c.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mods: c_int,
) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();

    if (action == c.GLFW_PRESS) {
        event.* = Event{
            .KeyPressed = .{
                .window = window,
                .key = @intToEnum(Key, key),
                .scancode = scancode,
                .mods = @intCast(u32, mods),
            },
        };
    } else if (action == c.GLFW_RELEASE) {
        event.* = Event{
            .KeyReleased = .{
                .window = window,
                .key = @intToEnum(Key, key),
                .scancode = scancode,
                .mods = @intCast(u32, mods),
            },
        };
    } else if (action == c.GLFW_REPEAT) {
        event.* = Event{
            .KeyRepeated = .{
                .window = window,
                .key = @intToEnum(Key, key),
                .scancode = scancode,
                .mods = @intCast(u32, mods),
            },
        };
    }
}

fn charCallbackGLFW(window: ?*c.GLFWwindow, codepoint: u32) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .CodepointInput = .{.window = window, .codepoint = codepoint},
    };
}

fn windowMaximizeCallbackGLFW(window: ?*c.GLFWwindow, maximized: c_int) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = if (maximized != 0) 
        Event{.WindowMaximized = .{.window = window}}
    else 
        Event{.WindowUnmaximized = .{.window = window}};
}

fn windowContentScaleCallbackGLFW(window: ?*c.GLFWwindow, x: f32, y: f32) callconv(.C) void {
    var self: *Engine = @ptrCast(*Engine, 
        @alignCast(@alignOf(Engine), c.glfwGetWindowUserPointer(window)));

    var event = self.newEvent();
    event.* = Event{
        .WindowScaleChanged = .{
            .window = window,
            .x = x,
            .y = y,
        }
    };
}
