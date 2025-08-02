const std = @import("std");
const builtin = @import("builtin");

const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

pub fn hello(name: t.TinyStr(16)) ![]const u8 {
    var buf: [32]u8 = undefined;
    return std.fmt.bufPrint(&buf, "{f}, how be?", .{name});
}

pub fn target() ![]const u8 {
    var buf: [64]u8 = undefined;

    return std.fmt.bufPrint(&buf,
        \\Addon Target:
        \\   OS - {t}
        \\  CPU - {t}
        \\  ABI - {t}
        \\
    , .{
        builtin.os.tag,
        builtin.cpu.arch,
        builtin.abi,
    });
}
