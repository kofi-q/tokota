//! This is roughly equivalent to the code that gets run in `./main.zig` (with
//! some runtime validation checks skipped for simplicity).
//!
//! Intended to serve as an example of how one might choose to avoid the
//! built-in value conversions and handle those manually, when needed, for
//! either performance or flexibility reasons (e.g. skipping integer range
//! checks when there are external guarantees for the incoming JS values).

const tokota = @import("tokota");

comptime {
    tokota.exportModule(@This());
}

pub fn add(call: tokota.Call) !tokota.Val {
    const arg_a, const arg_b = try call.args(2);

    const a = try arg_a.float64(call.env);
    const b = try arg_b.float64(call.env);

    return call.env.float64(a + b);
}
