const std = @import("std");

const Addon = @import("../Addon.zig");
const tokota = @import("../tokota.zig");

pub const def_path = "_build/windows/node.def";
pub const def_name = "node.def";

/// Adds a build step for emitting a `node.def` module-definition file for
/// generating a stub DLL to link against.
///
/// Creates a `namedLazyPath("node.def")` build graph node representing the
/// output path to the generated file.
pub fn updateSource(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    dep_tokota: ?*std.Build.Dependency,
) *std.Build.Step.UpdateSourceFiles {
    const native_target = b.resolveTargetQuery(.{});

    const addon = Addon.create(b, .{
        .mode = mode,
        .target = native_target,
        .name = "emit_node_def",
        .output_dir = .{ .custom = "../_build/windows" },
        .root_source_file = b.path("_build/windows/emit_node_def.zig"),
        .tokota = .{ .dep = dep_tokota },
    });

    const emit = b.addSystemCommand(&.{"node"});
    emit.addFileArg(b.path("_build/windows/emit_node_def.js"));
    emit.addFileInput(b.path("_build/windows/emit_node_def.node"));
    emit.step.dependOn(&addon.install.step);

    const node_def = b.addUpdateSourceFiles();
    _ = node_def.addCopyFileToSource(emit.captureStdOut(), def_path);
    node_def.step.dependOn(&emit.step);

    return node_def;
}

/// Generates a `node.lib` stub DLL containing Node-API symbols to link against
/// when building for Windows targets.
///
/// > #### ⚠ NOTE
/// > Requires `addNodeDef` to have been called in the Tokota build root first.
pub fn build(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    target: std.Target,
    dep_tokota: ?*std.Build.Dependency,
) struct { *std.Build.Step.Run, std.Build.LazyPath } {
    const native_target = b.resolveTargetQuery(.{});

    const _dep_tokota = dep_tokota orelse b.dependency("tokota", .{
        .optimize = mode,
        .target = native_target,
    });

    const dlltool_arch = switch (target.cpu.arch) {
        .x86 => "i386",
        .x86_64 => "i386:x86-64",
        else => |arch| blk: {
            if (arch.isArm()) break :blk "arm";
            if (arch.isAARCH64()) break :blk "arm64";
            @panic(b.fmt("Unsupported Windows CPU: {}", .{arch}));
        },
    };

    var create_dll = b.addSystemCommand(&.{
        b.graph.zig_exe, "dlltool",
        "-m",            dlltool_arch,
        "-D",            "node.exe",
    });

    create_dll.addPrefixedFileArg("-d", _dep_tokota.namedLazyPath(def_name));
    const output_path = create_dll.addPrefixedOutputFileArg("-l", "node.lib");

    return .{ create_dll, output_path };
}
