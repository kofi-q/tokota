const n = @import("../napi.zig");
const t = @import("../root.zig");

pub extern fn napi_coerce_to_bool(
    env: t.Env,
    val: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_symbol(
    env: t.Env,
    description: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_get_boolean(env: t.Env, value: bool, res: *?t.Val) n.Status;

pub extern fn napi_get_global(env: t.Env, res: *?t.Val) n.Status;

pub extern fn napi_get_null(env: t.Env, res: *?t.Val) n.Status;

pub extern fn napi_get_undefined(env: t.Env, res: *?t.Val) n.Status;

pub extern fn napi_get_value_bool(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn node_api_symbol_for(
    env: t.Env,
    key_ptr: [*]const u8,
    key_len: usize,
    res: *?t.Val,
) n.Status;
