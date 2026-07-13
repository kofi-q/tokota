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
    const _dep_tokota = dep_tokota orelse b.dependency("tokota", .{
        .optimize = mode,
        .target = native_target,
    });

    const module = b.createModule(.{
        .imports = &.{.{
            .name = "tokota",
            .module = _dep_tokota.module("tokota"),
        }},
        .optimize = mode,
        .root_source_file = b.path("_build/linux/emit_libnode_source.zig"),
        .target = native_target,
    });

    const emit_libnode_source = b.addExecutable(.{
        .name = "emit_libnode_source",
        .root_module = module,
    });
    Addon.linkNodeStub(b, emit_libnode_source, .{ .dep_tokota = dep_tokota });

    check_step.dependOn(&b.addLibrary(.{
        .name = "check",
        .root_module = module,
    }).step);

    const emit = b.addRunArtifact(emit_libnode_source);

    const libnode_zig = b.addUpdateSourceFiles();
    _ = libnode_zig.addCopyFileToSource(emit.captureStdOut(.{}), src_path);
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
