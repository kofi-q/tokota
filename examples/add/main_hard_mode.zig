//! This is roughly equivalent to the code that gets run in `./main.zig`.
//!
//! Intended to serve as an example of how one might drop down into the
//! lower-level bindings when needed, as well as a demonstration of the
//! boilerplate that the higher-level abstractions seek to minimise.

const std = @import("std");
const n = @import("tokota").napi;
const t = @import("tokota");

/// Invoked by the Node runtime to determine which version of the Node-API the
/// addon depends on.
export fn node_api_module_get_api_version_v1() t.NapiVersion {
    return .v8;
}

/// Main entry point, invoked by Node runtime when the addon is imported in JS.
export fn napi_register_module_v1(env: t.Env, js_exports: t.Val) ?t.Val {
    // Create a new JS function bound to the `add` callback defined below:
    var fn_add: ?t.Val = null;
    var res = n.napi_create_function(env, "add", "add".len, add, null, &fn_add);
    res.check() catch |err| switch (err) {
        t.Err.PendingException => return null,
        else => fatal(err, "unexpected error"),
    };

    // Add the JS function to the exports object:
    res = n.napi_set_named_property(env, js_exports, "add", fn_add.?);
    res.check() catch |err| switch (err) {
        t.Err.PendingException => return null,
        else => fatal(err, "unexpected error"),
    };

    return js_exports;
}

/// Callback function satisfying the `napi_callback` signature.
fn add(env: t.Env, info: n.CallInfo) callconv(.c) ?t.Val {
    var args: [2]t.Val = undefined;
    var args_len: usize = args.len;

    // Extract arguments:
    var res = n.napi_get_cb_info(env, info, &args_len, &args, null, null);
    res.check() catch |err| switch (err) {
        t.Err.PendingException => return null,
        else => fatal(err, "unexpected error"),
    };

    // Convert args[0] to equivalent float:
    var a: f64 = undefined;
    res = n.napi_get_value_double(env, args[0], &a);
    res.check() catch |err| switch (err) {
        t.Err.PendingException => return null,

        t.Err.InvalidArg,
        t.Err.NumberExpected,
        => return throw(env, err, "Invalid arg at index 0"),

        else => fatal(err, "unexpected error"),
    };

    // Convert args[1] to equivalent float:
    var b: f64 = undefined;
    res = n.napi_get_value_double(env, args[1], &b);
    res.check() catch |err| switch (err) {
        t.Err.PendingException => return null,

        t.Err.InvalidArg,
        t.Err.NumberExpected,
        => return throw(env, err, "Invalid arg at index 1"),

        else => fatal(err, "unexpected error"),
    };

    // Create a new JS value for the sum:
    var out: ?t.Val = null;
    res = n.napi_create_double(env, a + b, &out);
    res.check() catch |err| switch (err) {
        t.Err.PendingException => return null,
        else => fatal(err, "unexpected error"),
    };

    return out;
}

fn fatal(err: anyerror, msg: []const u8) noreturn {
    const code: []const u8 = @errorName(err);
    n.napi_fatal_error(code.ptr, code.len, msg.ptr, msg.len);
}

fn throw(env: t.Env, err: anyerror, msg: [:0]const u8) ?t.Val {
    const res = n.napi_throw_error(env, @errorName(err), msg);

    res.check() catch |err_throw| switch (err_throw) {
        t.Err.PendingException => return null,
        else => fatal(err_throw, "unexpected error"),
    };

    return null;
}
