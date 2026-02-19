const std = @import("std");

const Addon = @import("../Addon.zig");

pub const src_path = "_build/windows/napi_proxy.zig";
pub const src_name = "napi_proxy.zig";

/// Adds a build step for emitting a `napi_proxy.zig` source file containing
/// runtime Node-API symbol forwarders for Windows builds.
///
/// Creates a `namedLazyPath("napi_proxy.zig")` build graph node representing
/// the output path to the generated file.
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
        .root_source_file = b.path("_build/windows/emit_napi_proxy.zig"),
        .target = native_target,
    });

    const emit_napi_proxy = b.addExecutable(.{
        .name = "emit_napi_proxy",
        .root_module = module,
    });
    Addon.linkNodeStub(b, emit_napi_proxy, .{ .dep_tokota = dep_tokota });

    check_step.dependOn(&b.addLibrary(.{
        .name = "check",
        .root_module = module,
    }).step);

    const emit = b.addRunArtifact(emit_napi_proxy);

    const generated = b.addUpdateSourceFiles();
    _ = generated.addCopyFileToSource(emit.captureStdOut(.{}), src_path);
    generated.step.dependOn(&emit.step);

    return generated;
}
