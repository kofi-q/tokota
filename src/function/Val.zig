const Env = @import("../root.zig").Env;
const Val = @import("../root.zig").Val;
const Fn = @import("Fn.zig");

/// Wraps the value in a `Fn`, enabling function-related operations.
///
/// This performs no JS type checks and attempts to call `Fn` methods for a
/// non-function value will result in error. If using this to convert an
/// incoming function argument, consider receiving a `Fn` directly instead,
/// which will validate the JS type before conversion. Alternatively a
/// `Val.typeOf()` check can be used.
pub fn function(self: Val, env: Env) Fn {
    return .{ .env = env, .ptr = self };
}

pub fn functionTyped(
    self: Val,
    env: Env,
    comptime arg_types: anytype,
    comptime ReturnType: type,
) Fn.Typed(arg_types, ReturnType) {
    return .{
        .inner = .{
            .env = env,
            .ptr = self,
        },
    };
}
