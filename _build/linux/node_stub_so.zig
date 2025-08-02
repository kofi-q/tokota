const std = @import("std");

const Addon = @import("../Addon.zig");
const tokota = @import("../tokota.zig");

pub const src_path = "_build/linux/libnode.zig";
pub const src_name = "libnode.zig";

pub fn updateSource(
    b: *std.Build,
    check_step: *std.Build.Step,
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
    check_step.dependOn(&b.addLibrary(.{
        .name = "check",
        .root_module = addon.root_module,
    }).step);

    const emit = b.addSystemCommand(&.{"node"});
    emit.addFileArg(b.path("_build/linux/emit_libnode_source.js"));
    emit.addFileInput(b.path("_build/linux/emit_libnode_source.node"));
    emit.step.dependOn(&addon.install.step);

    const libnode_zig = b.addUpdateSourceFiles();
    _ = libnode_zig.addCopyFileToSource(emit.captureStdOut(), src_path);
    libnode_zig.step.dependOn(&emit.step);

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
            .root_source_file = _dep_tokota.namedLazyPath(src_name),
            .target = target,
        }),
    });
}
