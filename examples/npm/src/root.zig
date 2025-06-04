const std = @import("std");
const builtin = @import("builtin");

const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

pub fn hello(name: t.TinyStr(16)) ![]const u8 {
    var buf: [32]u8 = undefined;
    return std.fmt.bufPrint(&buf, "{}, how be?", .{name});
}

pub fn target() ![]const u8 {
    var buf: [64]u8 = undefined;

    return std.fmt.bufPrint(&buf,
        \\Addon Target:
        \\  OS  - {s}
        \\  CPU - {s}
        \\  ABI - {?s}
        \\
    , .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        switch (builtin.os.tag) {
            .linux => @tagName(builtin.abi),
            else => @as(?[]const u8, null),
        },
    });
}
