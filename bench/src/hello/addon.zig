const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

pub fn hello() []const u8 {
    return "world";
}
