const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const node = b.dependency("node", .{
        .target = target,
        .optimize = optimize,
    });
    const node_headers = node.path("include/node");

    // Define shared library which will be the .node artifact
    {
        const lib = b.addSharedLibrary(.{
            .name = "node-zig",
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        });

        lib.addIncludePath(node_headers);
        lib.linker_allow_shlib_undefined = true;

        b.getInstallStep()
            .dependOn(&b.addInstallArtifact(lib, .{ .dest_sub_path = "node-zig.node" }).step);
    }

    // Define unit tests for the library
    {
        const lib_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        });
        lib_unit_tests.addIncludePath(node_headers);

        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_unit_tests.step);
    }
}
