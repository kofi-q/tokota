//! `Env` API methods for creating and managing JS error values and exceptions.

const std = @import("std");

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Err = @import("error.zig").Err;
const ErrorDetails = @import("types.zig").ErrorDetails;
const ErrorInfo = @import("types.zig").ErrorInfo;
const panic = @import("error.zig").panic;
const requireNapiVersion = @import("../features.zig").requireNapiVersion;
const Val = @import("../root.zig").Val;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_error
pub fn err(self: Env, msg: anytype, code: anytype) !Val {
    return errCreate(self, n.napi_create_error, msg, code);
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_range_error
pub fn errRange(self: Env, msg: anytype, code: anytype) !Val {
    return errCreate(self, n.napi_create_range_error, msg, code);
}

/// https://nodejs.org/docs/latest/api/n-api.html#node_api_create_syntax_error
pub fn errSyntax(self: Env, msg: anytype, code: anytype) !Val {
    requireNapiVersion(.v9);

    return errCreate(self, n.node_api_create_syntax_error, msg, code);
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_type_error
pub fn errType(self: Env, msg: anytype, code: anytype) !Val {
    return errCreate(self, n.napi_create_type_error, msg, code);
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_exception_pending
pub fn isExceptionPending(self: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_exception_pending(self, &res).check();

    return res;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_last_error_info
pub fn lastNapiErr(self: Env) !*const ErrorInfo {
    var info: ?*const ErrorInfo = null;
    try n.napi_get_last_error_info(self, &info).check();

    return info.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_and_clear_last_exception
pub fn lastExceptionGetAndClear(self: Env) !Val {
    var ptr: ?Val = null;
    try n.napi_get_and_clear_last_exception(self, &ptr).check();

    return ptr.?;
}

/// Throws `err_val` as a JS exception and returns `Err.PendingException`, which
/// can be bubbled up to the Tokota call handler to return execution to JS. If
/// `err_val` is non-`Val`, it is first converted to a corresponding JS `Val`,
/// if inferred conversion is supported.
///
/// Returns a corresponding Node-API `Err` if the exception was not
/// successfully thrown.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn assert(call: t.Call, condition: bool) !void {
///     if (!condition) return call.env.throw("Assertion failed!");
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_throw
pub fn throw(self: Env, err_val: anytype) Err {
    try n.napi_throw(self, try self.infer(err_val)).check();
    return Err.PendingException;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_throw_error
pub fn throwErr(self: Env, details: ErrorDetails) Err {
    try n.napi_throw_error(
        self,
        @ptrCast(details.code),
        @ptrCast(details.msg),
    ).check();

    return Err.PendingException;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_throw_error
pub fn throwErrCode(self: Env, code: anyerror, msg: [:0]const u8) Err {
    try n.napi_throw_error(self, @errorName(code), @ptrCast(msg)).check();

    return Err.PendingException;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_throw_range_error
pub fn throwErrRange(self: Env, details: ErrorDetails) Err {
    try n.napi_throw_range_error(
        self,
        @ptrCast(details.code),
        @ptrCast(details.msg),
    ).check();

    return Err.PendingException;
}

/// https://nodejs.org/docs/latest/api/n-api.html#node_api_throw_syntax_error
pub fn throwErrSyntax(self: Env, details: ErrorDetails) Err {
    requireNapiVersion(.v9);

    try n.node_api_throw_syntax_error(
        self,
        @ptrCast(details.code),
        @ptrCast(details.msg),
    ).check();

    return Err.PendingException;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_throw_error
pub fn throwErrType(self: Env, details: ErrorDetails) Err {
    try n.napi_throw_type_error(
        self,
        @ptrCast(details.code),
        @ptrCast(details.msg),
    ).check();

    return Err.PendingException;
}

/// Triggers a JS 'uncaughtException' with `err_val`. Useful if an async
/// callback throws an exception with no way to recover. If `err_val` is
/// non-`Val`, it is first converted to a corresponding JS `Val`, if inferred
/// conversion is supported.
///
/// Returns `Err.PendingException`, which can be bubbled up to the Tokota
/// call handler to return execution to JS.
///
/// Returns a corresponding Node-API `Err` if the exception was not
/// successfully thrown.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn assertFatal(call: t.Call, condition: bool) !void {
///     if (!condition) return call.env.throwFatal("Assertion failed!");
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_fatal_exception
pub fn throwFatal(self: Env, err_val: Val) Err!void {
    try n.napi_fatal_exception(self, self.infer(err_val)).check();
    return Err.PendingException;
}

/// Convenience wrapper for `throw` that panics with the error message if
/// the Node-Api throw fails.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_throw_error
pub fn throwOrPanic(self: Env, details: ErrorDetails) void {
    switch (self.throwErr(details)) {
        Err.PendingException => {},
        else => panic(details.msg, details.code),
    }
}

fn errCreate(
    env: Env,
    comptime napi_method: fn (
        env: Env,
        code: ?Val,
        msg: Val,
        result: *?Val,
    ) callconv(.c) n.Status,
    msg: anytype,
    code: anytype,
) !Val {
    var ptr: ?Val = null;

    try @call(.auto, napi_method, .{
        env,
        try stringVal(env, code),
        (try stringVal(env, msg)).?,
        &ptr,
    }).check();

    return ptr.?;
}

fn stringVal(env: Env, str: anytype) !?Val {
    const Str = switch (@TypeOf(str)) {
        void => return null,
        else => |T| switch (@typeInfo(T)) {
            .optional => |opt_info| if (str == null)
                return null
            else
                opt_info.child,

            else => T,
        },
    };

    return switch (Str) {
        Val => str,

        [*:0]u8,
        [*:0]const u8,
        => env.stringZ(str),

        else => switch (@typeInfo(Str)) {
            .error_set => env.string(@errorName(str)),
            else => env.string(str),
        },
    };
}
