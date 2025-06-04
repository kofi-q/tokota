const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Object = @import("../root.zig").Object;
const Val = @import("../root.zig").Val;

/// Retrieves a native data previously attached to the JS value via
/// `Env.external()`.
///
/// Returns `Err.InvalidArg` for non-external JS values or those with different
/// external value types. The latter is enforced using `Object.Tag`s.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_external
pub fn external(self: Val, comptime T: type, env: Env) !T {
    const tag = Object.Tag.require(T);
    if (!try Object.tagCheck(.{ .env = env, .ptr = self }, tag)) {
        return error.InvalidArg;
    }

    var result: ?T = null;
    try n.napi_get_value_external(env, self, @ptrCast(&result)).check();

    return result.?;
}
