//! Array-specific methods of the `Val` API.

const Array = @import("Array.zig");
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// Returns an `Array` wrapper for this JS value, to enable array-specific
/// operations, if supported by the underlying JS type..
pub fn array(self: Val, env: Env) Array {
    return .{ .env = env, .ptr = self };
}

/// Returns `true` iff this is a JS `Array` object.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_array
pub fn isArray(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_array(env, self, &res).check();

    return res;
}
