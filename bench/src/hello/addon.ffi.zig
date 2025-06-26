const std = @import("std");
const n = @import("tokota").napi;
const t = @import("tokota");

export fn node_api_module_get_api_version_v1() t.NapiVersion {
    return .v8;
}

export fn napi_register_module_v1(env: t.Env, exports: t.Val) ?t.Val {
    const res = n.napi_define_properties(env, exports, 1, &.{.{
        .attributes = t.Property.Attributes.method,
        .name = "hello",
        .method_cb = hello,
    }});

    std.debug.assert(res == .ok);

    return exports;
}

fn hello(env: t.Env, _: n.CallInfo) callconv(.c) ?t.Val {
    var world: ?t.Val = null;
    const res = n.napi_create_string_utf8(env, "world", "world".len, &world);

    std.debug.assert(res == .ok);

    return world;
}
