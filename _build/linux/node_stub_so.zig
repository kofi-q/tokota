const std = @import("std");

const tokota = @import("../tokota.zig");

pub fn addLibNode(b: *std.Build, mode: std.builtin.OptimizeMode) void {
    const native_target = b.resolveTargetQuery(.{});

    const mod_tokota_native = b.createModule(
        tokota.moduleOpts(b, mode, native_target),
    );

    const exe_emit_stub_src = b.addExecutable(.{
        .name = "emit_libnode_stub",
        .root_module = b.createModule(.{
            .imports = &.{
                .{ .name = "tokota", .module = mod_tokota_native },
            },
            .optimize = .Debug,
            .root_source_file = b.path("_build/linux/emit_node_stub_so.zig"),
            .target = b.resolveTargetQuery(.{}),
        }),
    });
    const emit_stub_src = b.addRunArtifact(exe_emit_stub_src);

    const libnode_zig = b.addWriteFiles();
    libnode_zig.step.dependOn(&emit_stub_src.step);

    b.addNamedLazyPath("libnode.zig", libnode_zig.addCopyFile(
        emit_stub_src.captureStdOut(),
        "tokota-build/linux/libnode.zig",
    ));
}

pub fn build(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    target: ?std.Build.ResolvedTarget,
    dep_tokota: ?*std.Build.Dependency,
) *std.Build.Step.Compile {
    const native_target = b.resolveTargetQuery(.{});

    const _dep_tokota = dep_tokota orelse b.dependency("tokota", .{
        .optimize = mode,
        .target = native_target,
    });

    return b.addLibrary(.{
        .linkage = .dynamic,
        .name = "node-stub",
        .root_module = b.createModule(.{
            .optimize = mode,
            .root_source_file = _dep_tokota.namedLazyPath("libnode.zig"),
            .target = target,
        }),
    });
}
