const std = @import("std");

const tokota = @import("../tokota.zig");

/// Adds a build step for emitting a `node.def` module-definition file for
/// generating a stub DLL to link against.
///
/// Creates a `namedLazyPath("node.def")` build graph node representing the
/// output path to the generated file.
pub fn addNodeDef(b: *std.Build, mode: std.builtin.OptimizeMode) void {
    const native_target = b.resolveTargetQuery(.{});

    const mod_tokota_native = b.createModule(
        tokota.moduleOpts(b, mode, native_target),
    );

    const emit_symbols_exe = b.addExecutable(.{
        .name = "emit_dll_symbols",
        .root_module = b.createModule(.{
            .imports = &.{
                .{ .name = "tokota", .module = mod_tokota_native },
            },
            .optimize = mode,
            .root_source_file = b.path("_build/windows/emit_node_def.zig"),
            .target = native_target,
        }),
    });
    const emit_symbols_run = b.addRunArtifact(emit_symbols_exe);

    const node_def = b.addWriteFiles();
    node_def.step.dependOn(&emit_symbols_run.step);

    b.addNamedLazyPath("node.def", node_def.addCopyFile(
        emit_symbols_run.captureStdOut(),
        "tokota-build/windows/node.def",
    ));
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

    create_dll.addPrefixedFileArg("-d", _dep_tokota.namedLazyPath("node.def"));
    const output_path = create_dll.addPrefixedOutputFileArg("-l", "node.lib");

    return .{ create_dll, output_path };
}
