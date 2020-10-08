const std = @import("std");
const mem = std.mem;
const Builder = std.build.Builder;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;

pub fn build(b: *Builder) !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("renderer", "src/main.zig");
    exe.setTarget(target);

    exe.linkLibC();
    exe.linkSystemLibrary("c++");
    exe.addIncludeDir("thirdparty/tinyshader/tinyshader");
    exe.addIncludeDir("thirdparty/rendergraph/rendergraph");
    exe.addIncludeDir("thirdparty/glfw/include");

    if (target.getOs().tag == .linux) {
        exe.linkSystemLibrary("X11");
        exe.linkSystemLibrary("Xau");
    }

    if (target.getOs().tag == .windows) {
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("ole32");
        exe.linkSystemLibrary("oleaut32");
        exe.linkSystemLibrary("advapi32");
        exe.linkSystemLibrary("shlwapi");
    }

    exe.addCSourceFile("thirdparty/glfw/unity.c", &[_][]u8{});
    exe.addCSourceFile("thirdparty/rendergraph/rendergraph/vk_mem_alloc.cpp", &[_][]const u8{"-w"});
    exe.addCSourceFile("thirdparty/rendergraph/rendergraph/rendergraph.c", &[_][]u8{});
    exe.addCSourceFile("thirdparty/rendergraph/rendergraph/rendergraph_ext.c", &[_][]u8{});
    exe.addCSourceFile("thirdparty/tinyshader/tinyshader/tinyshader_unity.c", &[_][]u8{});

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
