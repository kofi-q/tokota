const std = @import("std");

pub const AddonTarget = struct {
    query: std.Target.Query,
    win32_runtime: Runtime = .node,
};

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

pub fn nodeOs(tag: std.Target.Os.Tag) []const u8 {
    return switch (tag) {
        .macos => "darwin",
        .solaris => "sunos",
        .windows => "win32",
        else => @tagName(tag),
    };
}

pub fn nodeTriple(
    b: *std.Build,
    target: std.Target,
    win32_runtime: Runtime,
) []const u8 {
    return switch (target.os.tag) {
        .linux => b.fmt("{s}-{s}-{s}", .{
            nodeOs(.linux),
            nodeCpu(target),
            nodeAbi(target).?,
        }),
        .windows => b.fmt("{s}-{s}-{t}", .{
            nodeOs(.windows),
            nodeCpu(target),
            win32_runtime,
        }),
        else => b.fmt("{s}-{s}", .{
            nodeOs(target.os.tag),
            nodeCpu(target),
        }),
    };
}

pub fn packageName(
    b: *std.Build,
    lib_name: []const u8,
    scoped_bin_packages: bool,
    target: std.Target,
    win32_runtime: Runtime,
) []const u8 {
    const prefix = if (!scoped_bin_packages or lib_name[0] == '@')
        b.fmt("{s}-", .{lib_name})
    else
        b.fmt("@{s}/", .{lib_name});

    return b.fmt("{s}{s}", .{
        prefix,
        switch (target.os.tag) {
            .linux => b.fmt("{t}-{t}-{t}", .{
                target.os.tag,
                target.cpu.arch,
                target.abi,
            }),
            .windows => b.fmt("{t}-{t}-{t}", .{
                target.os.tag,
                target.cpu.arch,
                win32_runtime,
            }),
            else => b.fmt("{t}-{t}", .{
                target.os.tag,
                target.cpu.arch,
            }),
        },
    });
}

pub const Runtime = enum {
    bun,
    deno,
    electron,
    node,

    pub fn nameLenMax() comptime_int {
        return @tagName(Runtime.electron).len;
    }
};
