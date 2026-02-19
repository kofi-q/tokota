const std = @import("std");

const Addon = @import("../Addon.zig");

pub const src_path = "_build/windows/napi_forward.zig";
pub const src_name = "napi_forward.zig";

/// Adds a build step for emitting a `napi_forward.zig` source file containing
/// runtime Node-API symbol forwarders for Windows builds.
///
/// Creates a `namedLazyPath("napi_forward.zig")` build graph node representing
/// the output path to the generated file.
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
        .name = "emit_napi_forward",
        .output_dir = .{ .custom = "../_build/windows" },
        .root_source_file = b.path("_build/windows/emit_napi_forward.zig"),
        .tokota = .{ .dep = dep_tokota },
    });
    check_step.dependOn(&b.addLibrary(.{
        .name = "check",
        .root_module = addon.root_module,
    }).step);

    const emit = b.addSystemCommand(&.{"node"});
    emit.addFileArg(b.path("_build/windows/emit_napi_forward.js"));
    emit.addFileInput(b.path("_build/windows/emit_napi_forward.node"));
    emit.step.dependOn(&addon.install.step);

    const generated = b.addUpdateSourceFiles();
    _ = generated.addCopyFileToSource(emit.captureStdOut(.{}), src_path);
    generated.step.dependOn(&emit.step);

    return generated;
}
