const std = @import("std");
const builtin = @import("builtin");
const options = @import("src/options.zig");
const mem = std.mem;
const Builder = std.build.Builder;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;

var target: std.zig.CrossTarget = undefined;
var mode: builtin.Mode = undefined;
var renderer_lib: *std.build.LibExeObjStep = undefined;
var stb_image_lib: *std.build.LibExeObjStep = undefined;
var renderer_pkg = std.build.Pkg {
    .name = "renderer",
    .path = "src/main.zig",
};

fn addExample(b: *Builder, comptime name: []const u8) !void {
    const exe = b.addExecutable(name, "examples/" ++ name ++ ".zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    if (target.getOs().tag == .windows) {
        exe.subsystem = .Windows;
    }

    exe.addIncludeDir("thirdparty/glfw/include");
    exe.addPackage(renderer_pkg);
    exe.linkLibrary(renderer_lib);
    exe.linkLibrary(stb_image_lib);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run-" ++ name, "Run the example \"" ++ name ++ "\"");
    run_step.dependOn(&run_cmd.step);
}

pub fn build(b: *Builder) !void {
    target = b.standardTargetOptions(.{});
    if (target.getOs().tag == .windows) target.abi = std.builtin.Abi.gnu;
    mode = b.standardReleaseOptions();

    stb_image_lib = b.addStaticLibrary("renderer", null);
    stb_image_lib.setTarget(target);
    stb_image_lib.setBuildMode(mode);
    stb_image_lib.linkLibC();
    stb_image_lib.addCSourceFile("thirdparty/stb_image/stb_image.c", &[_][]u8{});
    stb_image_lib.disable_sanitize_c = true;

    renderer_lib = b.addStaticLibrary("renderer", null);
    renderer_lib.setTarget(target);
    renderer_lib.setBuildMode(mode);

    renderer_lib.linkLibC();
    renderer_lib.linkSystemLibrary("c++");

    if (target.getOs().tag == .linux) {
        if (options.use_wayland) {
            renderer_lib.linkSystemLibrary("wayland-client");
        } else {
            renderer_lib.linkSystemLibrary("X11");
            renderer_lib.linkSystemLibrary("Xau");
        }
    }

    if (target.getOs().tag == .windows) {
        renderer_lib.linkSystemLibrary("gdi32");
        renderer_lib.linkSystemLibrary("user32");
        renderer_lib.linkSystemLibrary("ole32");
        renderer_lib.linkSystemLibrary("oleaut32");
        renderer_lib.linkSystemLibrary("advapi32");
        renderer_lib.linkSystemLibrary("shlwapi");
    }

    if (target.getOs().tag == .linux) {
        if (options.use_wayland) {
            renderer_lib.addCSourceFile(
                "thirdparty/glfw/glfw_unity.c", &[_][]const u8{"-D_GLFW_WAYLAND"});
        } else {
            renderer_lib.addCSourceFile(
                "thirdparty/glfw/glfw_unity.c", &[_][]const u8{"-D_GLFW_X11"});
        }
    } else {
        renderer_lib.addCSourceFile(
            "thirdparty/glfw/glfw_unity.c", &[_][]u8{});
    }

    renderer_lib.addCSourceFile(
        "thirdparty/rendergraph/rendergraph/vk_mem_alloc.cpp", &[_][]const u8{"-w"});
    renderer_lib.addCSourceFile(
        "thirdparty/rendergraph/rendergraph/rendergraph.c", &[_][]u8{});
    renderer_lib.addCSourceFile(
        "thirdparty/rendergraph/rendergraph/rendergraph_ext.c", &[_][]u8{});
    renderer_lib.addCSourceFile(
        "thirdparty/tinyshader/tinyshader/tinyshader_unity.c", &[_][]u8{});
    renderer_lib.addCSourceFile("thirdparty/cgltf/cgltf.c", &[_][]u8{});
    renderer_lib.addCSourceFile("thirdparty/zstd/zstddeclib.c", &[_][]u8{});

    const renderer_test = b.addTest("src/tests.zig");

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&renderer_test.step);

    try addExample(b, "noise");
    try addExample(b, "model");
    try addExample(b, "compute");
}
