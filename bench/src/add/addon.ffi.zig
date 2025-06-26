const std = @import("std");
const n = @import("tokota").napi;
const t = @import("tokota");

export fn node_api_module_get_api_version_v1() t.NapiVersion {
    return .v8;
}

export fn napi_register_module_v1(env: t.Env, exports: t.Val) ?t.Val {
    const res = n.napi_define_properties(env, exports, 1, &.{.{
        .attributes = t.Property.Attributes.method,
        .name = "add",
        .method_cb = add,
    }});

    std.debug.assert(res == .ok);

    return exports;
}

fn add(env: t.Env, info: n.CallInfo) callconv(.c) ?t.Val {
    var args: [2]t.Val = undefined;
    var args_len: usize = args.len;

    var res = n.napi_get_cb_info(env, info, &args_len, &args, null, null);
    std.debug.assert(res == .ok);

    var a: f64 = undefined;
    res = n.napi_get_value_double(env, args[0], &a);
    std.debug.assert(res == .ok);

    var b: f64 = undefined;
    res = n.napi_get_value_double(env, args[1], &b);
    std.debug.assert(res == .ok);

    var sum: ?t.Val = null;
    res = n.napi_create_double(env, a + b, &sum);
    std.debug.assert(res == .ok);

    return sum;
}
