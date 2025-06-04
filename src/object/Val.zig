const std = @import("std");

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;
const Class = @import("Class.zig");
const Object = @import("Object.zig");

/// Wraps this value in a `Class`, enabling instance construction, if needed.
/// No runtime checks are performed here to assert the underlying value is a
/// class and attempting to later construct instances from a non-class value
/// will result in an error.
pub fn class(self: Val, env: Env) Class {
    return .{ .env = env, .ptr = self };
}

/// `true` iff this JS value is an instance of `js_class`, which can either be
/// a `Class` or `Val` representing a JS class.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_instanceof
pub fn instanceOf(self: Val, env: Env, js_class: anytype) !bool {
    var result: bool = undefined;
    try n.napi_instanceof(env, self, switch (@TypeOf(js_class)) {
        Class => js_class.ptr,
        Val => js_class,

        else => |T| @compileError(std.fmt.comptimePrint(
            "Expected `Class` or `Val` in `Val.instanceOf()`, got {s}",
            .{@typeName(T)},
        )),
    }, &result).check();
    return result;
}

/// Wraps this value in an `Object`, enabling objet/field access/manipulation,
/// if needed. No runtime checks are performed here to assert the underlying
/// value is an object and attempting to later perform `Object`-specific
/// operations on a non-object value will result in an error.
pub fn object(self: Val, env: Env) Object {
    return .{ .ptr = self, .env = env };
}

/// Coerces the underlying, potentially non-object value to a JS `Object` value.
///
/// Returns an `Object`containing a newly allocated `Val`. The original `Val`
/// remains unchanged.
///
/// https://nodejs.org/api/n-api.html#napi_coerce_to_object
pub fn objectCoerce(self: Val, env: Env) !Object {
    var res: ?Val = null;
    try n.napi_coerce_to_object(env, self, &res).check();

    return .{ .env = env, .ptr = res.? };
}
