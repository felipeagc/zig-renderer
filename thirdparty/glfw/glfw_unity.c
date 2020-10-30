#ifdef __linux__

#if defined(_GLFW_X11)
    #include "src/x11_init.c"
    #include "src/x11_monitor.c"
    #include "src/x11_window.c"
    #include "src/xkb_unicode.c"
    #include "src/glx_context.c"
#endif

#if defined(_GLFW_WAYLAND)
    #include "src/wl_init.c"
    #include "src/wl_monitor.c"
    #include "src/wl_window.c"
    #include "src/xkb_unicode.c"

    #include "src/wayland-idle-inhibit-unstable-v1-protocol.c"
    #include "src/wayland-pointer-constraints-unstable-v1-protocol.c"
    #include "src/wayland-relative-pointer-unstable-v1-protocol.c"
    #include "src/wayland-viewporter-protocol.c"
    #include "src/wayland-xdg-decoration-protocol.c"
    #include "src/wayland-xdg-shell-protocol.c"
#endif

#include "src/posix_time.c"
#include "src/posix_thread.c"
#include "src/egl_context.c"
#include "src/osmesa_context.c"
#include "src/linux_joystick.c"

#endif

#ifdef _WIN32

#define _GLFW_WIN32

#include "src/win32_init.c"
#include "src/win32_joystick.c"
#include "src/win32_monitor.c"
#include "src/win32_time.c"
#include "src/win32_thread.c"
#include "src/win32_window.c"
#include "src/wgl_context.c"
#include "src/egl_context.c"
#include "src/osmesa_context.c"

#endif

#include "src/context.c"
#include "src/init.c"
#include "src/input.c"
#include "src/monitor.c"
#include "src/vulkan.c"
#include "src/window.c"
