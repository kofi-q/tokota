const std = @import("std");
const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

pub fn add(a: f64, b: f64) f64 {
    return a + b;
}
