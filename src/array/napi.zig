const n = @import("../napi.zig");
const t = @import("../root.zig");

pub extern fn napi_create_array_with_length(
    env: t.Env,
    len: usize,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_array(env: t.Env, res: *?t.Val) n.Status;

pub extern fn napi_delete_element(
    env: t.Env,
    arr: t.Val,
    idx: u32,
    res: ?*bool,
) n.Status;

pub extern fn napi_get_array_length(env: t.Env, arr: t.Val, res: *u32) n.Status;

pub extern fn napi_get_element(
    env: t.Env,
    arr: t.Val,
    idx: u32,
    res: *?t.Val,
) n.Status;

pub extern fn napi_has_element(
    env: t.Env,
    arr: t.Val,
    idx: u32,
    res: *bool,
) n.Status;

pub extern fn napi_is_array(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn napi_set_element(
    env: t.Env,
    arr: t.Val,
    idx: u32,
    val: ?t.Val,
) n.Status;
