const std = @import("std");
const tokota = @import("tokota");

comptime {
    // Public functions of exported modules are exposed as JS functions.
    tokota.exportModule(@This());
}

pub fn hello(name: tokota.TinyStr(16)) ![]const u8 {
    var buf: [32]u8 = undefined;

    // Built-in return value conversion is available for simple types.
    return std.fmt.bufPrint(&buf, "{f}, how be?", .{name});
}
