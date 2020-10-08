const std = @import("std");
const mem = std.mem;
const Builder = std.build.Builder;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const ArrayList = std.ArrayList;

fn addCppFile(
        b: *Builder,
        exe: *std.build.LibExeObjStep,
        comptime input: []const u8,
        comptime output: []const u8,
        args: []const []const u8,
    ) !void {
    const ext = if (exe.target.getOs().tag == .windows) ".obj" else ".o";
    const outputWithExt = try mem.concat(b.allocator, u8, &[_][]const u8{output, ext});
    defer b.allocator.free(outputWithExt);

    const triple = try exe.target.zigTriple(b.allocator);
    defer b.allocator.free(triple);
    const targetOption = try mem.concat(b.allocator, u8, &[_][]const u8{"--target=", triple});
    defer b.allocator.free(targetOption);

    var commandLine = ArrayList([]const u8).init(b.allocator);
    defer commandLine.deinit();

    try commandLine.append("zig");
    try commandLine.append("c++");
    try commandLine.append(input);
    try commandLine.append("-c");
    try commandLine.append("-w");
    try commandLine.append("-o");
    try commandLine.append(outputWithExt);
    try commandLine.append(targetOption);

    for (args) |arg| {
        if (mem.startsWith(u8, arg, "-I")) {
            try commandLine.append(arg);
        }
    }

    const cmd = b.addSystemCommand(commandLine.items);

    exe.step.dependOn(&cmd.step);
    exe.addObjectFile(outputWithExt);
}

pub fn build(b: *Builder) !void {
    var gpa = GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
    }

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("renderer", "src/main.zig");
    exe.setTarget(target);

    exe.linkLibC();
    exe.linkSystemLibrary("c++");
    exe.addIncludeDir("thirdparty/tinyshader");
    exe.addIncludeDir("thirdparty/rendergraph");
    exe.addIncludeDir("thirdparty/glfw/include");

    var cArgs = ArrayList([]const u8).init(&gpa.allocator);
    defer cArgs.deinit();
    try cArgs.append("-std=c11");
    try cArgs.append("-Ithirdparty/glfw/src");
    try cArgs.append("-Ithirdparty/glfw/include");
    try cArgs.append("-Ithirdparty/rendergraph");
    try cArgs.append("-Ithirdparty/rendergraph/rendergraph");
    try cArgs.append("-Ithirdparty/tinyshader");

    if (target.getOs().tag == .linux) {
        try cArgs.append("-I/usr/include");

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

    try addCppFile(b, exe, "thirdparty/rendergraph/rendergraph/vk_mem_alloc.cpp", "zig-cache/vma", cArgs.items);

    exe.addCSourceFile("thirdparty/glfw/unity.c", cArgs.items);
    exe.addCSourceFile("thirdparty/rendergraph/rendergraph/rendergraph.c", cArgs.items);
    exe.addCSourceFile("thirdparty/rendergraph/rendergraph/rendergraph_ext.c", cArgs.items);
    exe.addCSourceFile("thirdparty/tinyshader/tinyshader/tinyshader.c", cArgs.items);
    exe.addCSourceFile("thirdparty/tinyshader/tinyshader/tinyshader_misc.c", cArgs.items);
    exe.addCSourceFile("thirdparty/tinyshader/tinyshader/tinyshader_parser.c", cArgs.items);
    exe.addCSourceFile("thirdparty/tinyshader/tinyshader/tinyshader_analysis.c", cArgs.items);
    exe.addCSourceFile("thirdparty/tinyshader/tinyshader/tinyshader_ir.c", cArgs.items);

    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
