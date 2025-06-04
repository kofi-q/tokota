const n = @import("../napi.zig");
const t = @import("../root.zig");

pub extern fn napi_create_arraybuffer(
    env: t.Env,
    byte_length: usize,
    data: ?*[*]u8,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_buffer_copy(
    env: t.Env,
    length: usize,
    data: [*]const u8,
    result_data: ?*[*]u8,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_buffer(
    env: t.Env,
    length: usize,
    data: ?*[*]u8,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_dataview(
    env: t.Env,
    length: usize,
    array_buffer: t.Val,
    byte_offset: usize,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_external_arraybuffer(
    env: t.Env,
    data_ptr: [*]u8,
    data_len: usize,
    finalize_cb: ?n.FinalizeCb,
    finalize_hint: ?t.AnyPtrConst,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_external_buffer(
    env: t.Env,
    data_len: usize,
    data_ptr: [*]u8,
    finalize_cb: ?n.FinalizeCb,
    finalize_hint: ?t.AnyPtrConst,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_typedarray(
    env: t.Env,
    arr_type: t.ArrayType,
    length: usize,
    array_buffer: t.Val,
    byte_offset: usize,
    res: *?t.Val,
) n.Status;

pub extern fn napi_detach_arraybuffer(env: t.Env, array_buffer: t.Val) n.Status;

pub extern fn napi_get_arraybuffer_info(
    env: t.Env,
    array_buffer: t.Val,
    data: *?[*]u8,
    byte_length: *usize,
) n.Status;

pub extern fn napi_get_buffer_info(
    env: t.Env,
    val: t.Val,
    data: *?[*]u8,
    length: *usize,
) n.Status;

pub extern fn napi_get_dataview_info(
    env: t.Env,
    dataview: t.Val,
    data_len: ?*usize,
    data_ptr: ?*?[*]u8,
    array_buffer: ?*?t.Val,
    array_buffer_offset: ?*usize,
) n.Status;

pub extern fn napi_get_typedarray_info(
    env: t.Env,
    typedarray: t.Val,
    arr_type: *t.ArrayType,
    data_len: *usize,
    data_ptr: *?*anyopaque,
    array_buffer: ?*?t.Val,
    array_buffer_offset: ?*usize,
) n.Status;

pub extern fn napi_is_arraybuffer(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn napi_is_buffer(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn napi_is_dataview(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn napi_is_detached_arraybuffer(
    env: t.Env,
    val: t.Val,
    res: *bool,
) n.Status;

pub extern fn napi_is_typedarray(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn node_api_create_buffer_from_arraybuffer(
    env: t.Env,
    array_buffer: t.Val,
    byte_offset: usize,
    byte_length: usize,
    res: *?t.Val,
) n.Status;
