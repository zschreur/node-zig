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
        {
            const wf = b.addWriteFiles();
            const c_file_content =
                \\#include <node_api.h>
                \\#include <stdio.h>
                \\
                \\extern napi_value init(napi_env env, napi_value exports);
                \\
                \\NAPI_MODULE(
                // Separating it like this will allow the addon to be given a unique name
            ++ "node-zig" ++
                \\, init)
            ;

            const f = wf.add("node-zig.c", c_file_content);
            lib.addCSourceFile(.{
                .file = f,
                .flags = &.{ "-Wall", "-fPIC" },
            });
        }
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
