//! `Env` API methods for creating and accessing JS globals.

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Object = @import("../root.zig").Object;
const Symbol = @import("Symbol.zig");
const requireNapiVersion = @import("../features.zig").requireNapiVersion;
const Val = @import("../root.zig").Val;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_boolean
pub fn boolean(self: Env, val: bool) !Val {
    var out: ?Val = null;
    try n.napi_get_boolean(self, val, &out).check();

    return out.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_global
pub fn global(self: Env) !Object {
    var ptr: ?Val = null;
    try n.napi_get_global(self, &ptr).check();

    return ptr.?.object(self);
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_null
pub fn nullVal(self: Env) !Val {
    var val: ?Val = null;
    try n.napi_get_null(self, &val).check();

    return val.?;
}

pub fn orNull(env: Env, val: ?Val) !Val {
    return val orelse env.nullVal();
}

pub fn orUndefined(env: Env, val: ?Val) !Val {
    return val orelse env.undefinedVal();
}

/// Creates a new, unique JS [Symbol](https://mdn.io/Symbol) from the given
/// Zig or JS string.
///
/// Although symbols in JS can be created from other value
/// types, most Node-API implementations will return an error for anything other
/// than a string.
///
/// Equivalent to the following in JS:
/// ```js
/// Symbol(desc);
/// ```
///
/// > #### ⚠ NOTE
/// > This *always* creates a new `Symbol`, regardless of whether or
/// not another one already exists with the same string description. For
/// creating/retrieving Symbols in/from the global registry, use
/// `Env.symbolFor()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_symbol
pub fn symbol(self: Env, desc: anytype) !Symbol {
    var ptr: ?Val = null;

    try n.napi_create_symbol(
        self,
        switch (@TypeOf(desc)) {
            Val => desc,
            else => try self.string(desc),
        },
        &ptr,
    ).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// Returns the global JS [Symbol](https://mdn.io/Symbol) matching the given
/// key, if one exists, or a newly created one otherwise.
///
/// Equivalent to the following in JS:
/// ```js
/// Symbol.for(key);
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#node_api_symbol_for
pub fn symbolFor(self: Env, key: []const u8) !Symbol {
    requireNapiVersion(.v9);

    var ptr: ?Val = null;
    try n.node_api_symbol_for(self, key.ptr, key.len, &ptr).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_undefined
pub fn undefinedVal(self: Env) !Val {
    var val: ?Val = null;
    try n.napi_get_undefined(self, &val).check();

    return val.?;
}
