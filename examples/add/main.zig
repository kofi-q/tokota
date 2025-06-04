//! For a sense for what's going on under the hood here, take a look at
//! `./main_hard_mode.zig`.

const tokota = @import("tokota");

comptime {
    tokota.exportModule(@This());
}

pub fn add(a: f64, b: f64) f64 {
    return a + b;
}
