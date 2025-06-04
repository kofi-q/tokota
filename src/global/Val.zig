const std = @import("std");

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Symbol = @import("Symbol.zig");
const Val = @import("../root.zig").Val;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_bool
pub fn boolean(self: Val, env: Env) !bool {
    var val: bool = undefined;
    try n.napi_get_value_bool(env, self, &val).check();

    return val;
}

/// Coerces the underlying, potentially non-boolean value to a JS boolean value.
///
/// Returns a newly allocated `Val`. The original `Val` remains unchanged.
///
/// This is similar to the following in JS:
/// ```js
/// function boolCoerce(value) {
///   return Boolean(value);
/// }
/// ```
///
/// https://nodejs.org/api/n-api.html#napi_coerce_to_bool
pub fn boolCoerce(self: Val, env: Env) !Val {
    var val: ?Val = null;
    try n.napi_coerce_to_bool(env, self, &val).check();

    return val.?;
}

/// https://nodejs.org/api/n-api.html#napi_typeof
pub fn isNullOrUndefined(self: Val, env: Env) !bool {
    return switch (try self.typeOf(env)) {
        .null, .undefined => true,
        else => false,
    };
}

/// Wraps this value in a `Symbol`, enabling stricter typing and/or access to
/// `Symbol.ref()` (`Val.ref()` can be used directly if building against
/// `NapiVersion`.`v10`).
pub fn symbol(self: Val, env: Env) Symbol {
    return .{ .env = env, .ptr = self };
}
