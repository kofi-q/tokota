//! Async-specific methods of the `Val` API.

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Promise = @import("promise.zig").Promise;
const Val = @import("../root.zig").Val;

/// `true` iff the underlying value is a JS `Promise`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_promise
pub fn isPromise(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_promise(env, self, &res).check();

    return res;
}

/// Wraps this value in a `Promise`, to enable JS Promise-related operations.
///
/// > #### ⚠ NOTE
/// > No type validation is performed here and attempts to use `Promise`-related
/// methods on a non-Promise object will return errors. `Val.isPromise()` can be
/// used to perform a type check before casting, when needed.
pub fn promise(self: Val, env: Env) Promise {
    return .{ .env = env, .ptr = self };
}
