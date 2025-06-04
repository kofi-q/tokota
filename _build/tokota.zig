const std = @import("std");

pub fn imports(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) []const std.Build.Module.Import {
    return b.allocator.dupe(std.Build.Module.Import, &.{
        importBase(b, mode, target),
        .{
            .name = "options",
            .module = b.createModule(.{
                .optimize = mode,
                .root_source_file = b.path("options/root.zig"),
                .target = target,
            }),
        },
    }) catch @panic("OOM");
}

pub fn importBase(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) std.Build.Module.Import {
    return std.Build.Module.Import{
        .name = "base",
        .module = b.dependency("base", .{
            .optimize = mode,
            .target = target,
        }).module("base"),
    };
}

pub fn moduleOpts(
    b: *std.Build,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) std.Build.Module.CreateOptions {
    return .{
        .imports = imports(b, mode, target),
        .optimize = mode,
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    };
}
