const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add the raylib-zig dependency
    const raylib_pkg = b.dependency("raylib_pkg", .{});
    const raylib = raylib_pkg.module("raylib");

    const exe = b.addExecutable(.{
        .name = "UI_test",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("raylib", raylib);

    // Link required raylib system libs manually
    exe.linkLibrary(raylib_pkg.artifact("raylib"));
    exe.linkSystemLibrary("winmm");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("shell32");

    exe.subsystem = switch (optimize) {
        .Debug => .Console,
        else => .Windows,
    };

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}