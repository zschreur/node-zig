const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const node = b.dependency("node", .{
        .target = target,
        .optimize = optimize,
    });
    const node_headers = node.path("include/node");

    const lib = b.addStaticLibrary(.{
        .name = "node-zig",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(node_headers);
    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_unit_tests.addIncludePath(node_headers);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const nodeAddon = b.addSharedLibrary(.{
        .name = "addon",
        .target = target,
        .optimize = optimize,
    });

    nodeAddon.linker_allow_shlib_undefined = true;

    nodeAddon.linkLibrary(lib);
    nodeAddon.addIncludePath(node_headers);
    nodeAddon.linkLibC();
    nodeAddon.addCSourceFile(.{
        .file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/addon.c",
        } },
        .flags = &.{ "-Wall", "-fPIC" },
    });

    b.getInstallStep()
        .dependOn(&b.addInstallArtifact(nodeAddon, .{ .dest_sub_path = "addon.node" }).step);
}
