const std = @import("std");

const Addon = @import("../Addon.zig");
const tokota = @import("../tokota.zig");

pub fn updateSource(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    dep_tokota: ?*std.Build.Dependency,
) *std.Build.Step.UpdateSourceFiles {
    const native_target = b.resolveTargetQuery(.{});

    const addon = Addon.create(b, .{
        .mode = mode,
        .target = native_target,
        .name = "emit_libnode_source",
        .output_dir = .{ .custom = "../_build/linux" },
        .root_source_file = b.path("_build/linux/emit_libnode_source.zig"),
        .tokota = .{ .dep = dep_tokota },
    });

    const emit = b.addSystemCommand(&.{"node"});
    emit.addFileArg(b.path("_build/linux/emit_libnode_source.js"));
    emit.step.dependOn(&addon.install.step);

    const libnode_zig = b.addUpdateSourceFiles();
    libnode_zig.step.dependOn(&emit.step);

    const filename = "_build/linux/libnode.zig";
    _ = libnode_zig.addCopyFileToSource(emit.captureStdOut(), filename);

    b.addNamedLazyPath("libnode.zig", b.path(filename));

    return libnode_zig;
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
