const std = @import("std");

pub fn nodeAbi(target: std.Target) ?[]const u8 {
    if (target.os.tag != .linux) return null;
    if (target.abi.isGnu()) return "glibc";
    if (target.abi.isMusl()) return "musl";

    return @tagName(target.abi);
}

pub fn nodeCpu(target: std.Target) []const u8 {
    return switch (target.cpu.arch) {
        .aarch64 => "arm64",
        .loongarch64 => "loong64",
        .powerpc64 => "ppc64be",
        .powerpc64le => "ppc64le",
        .x86 => "ia32",
        .x86_64 => "x64",
        else => @tagName(target.cpu.arch),
    };
}

pub fn nodeOs(target: std.Target) []const u8 {
    return switch (target.os.tag) {
        .macos => "darwin",
        .solaris => "sunos",
        .windows => "win32",
        else => @tagName(target.os.tag),
    };
}

pub fn nodeTriple(b: *std.Build, target: std.Target) []const u8 {
    return switch (target.os.tag) {
        .linux => b.fmt("{s}-{s}-{s}", .{
            nodeOs(target),
            nodeCpu(target),
            nodeAbi(target).?,
        }),
        else => b.fmt("{s}-{s}", .{
            nodeOs(target),
            nodeCpu(target),
        }),
    };
}

pub fn packageName(
    b: *std.Build,
    lib_name: []const u8,
    scoped_bin_packages: bool,
    target: std.Target,
) []const u8 {
    const prefix = if (!scoped_bin_packages or lib_name[0] == '@')
        b.fmt("{s}-", .{lib_name})
    else
        b.fmt("@{s}/", .{lib_name});

    return b.fmt("{s}{s}", .{
        prefix,
        switch (target.os.tag) {
            .linux => b.fmt("{s}-{s}-{s}", .{
                @tagName(target.os.tag),
                @tagName(target.cpu.arch),
                @tagName(target.abi),
            }),
            else => b.fmt("{s}-{s}", .{
                @tagName(target.os.tag),
                @tagName(target.cpu.arch),
            }),
        },
    });
}
