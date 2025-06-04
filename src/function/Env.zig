//! `Env` API methods for creating JS `Fn` values.

const std = @import("std");
const builtin = @import("builtin");

const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Fn = @import("Fn.zig");
const napiCb = @import("callback.zig").napiCb;
const Val = @import("../root.zig").Val;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_function
pub fn function(self: Env, comptime cb: anytype) !Fn {
    var ptr: ?Val = null;
    try n.napi_create_function(self, null, 0, napiCb(cb, .{}), null, &ptr)
        .check();

    return .{ .env = self, .ptr = ptr.? };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_function
pub fn functionT(self: Env, comptime cb: anytype, data: anytype) !Fn {
    var ptr: ?Val = null;
    try n.napi_create_function(
        self,
        null,
        0,
        napiCb(cb, .{ .DataType = @TypeOf(data) }),
        data,
        &ptr,
    ).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_function
pub fn functionNamed(
    self: Env,
    name: []const u8,
    comptime cb: anytype,
) !Fn {
    var ptr: ?Val = null;
    try n.napi_create_function(
        self,
        name.ptr,
        name.len,
        napiCb(cb, .{}),
        null,
        &ptr,
    ).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_function
pub fn functionNamedT(
    self: Env,
    name: []const u8,
    comptime cb: anytype,
    data: anytype,
) !Fn {
    var ptr: ?Val = null;
    try n.napi_create_function(
        self,
        name.ptr,
        name.len,
        napiCb(cb, .{ .DataType = @TypeOf(data) }),
        data,
        &ptr,
    )
        .check();

    return .{ .env = self, .ptr = ptr.? };
}
