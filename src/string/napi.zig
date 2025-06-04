const n = @import("../napi.zig");
const t = @import("../root.zig");

pub extern fn napi_coerce_to_string(
    env: t.Env,
    js_any: t.Val,
    js_str: *?t.Val,
) n.Status;

pub extern fn napi_create_string_latin1(
    env: t.Env,
    str_ptr: [*]const u8,
    str_len: usize,
    js_str: *?t.Val,
) n.Status;

pub extern fn napi_create_string_utf16(
    env: t.Env,
    str_ptr: [*]const u16,
    str_len: usize,
    js_str: *?t.Val,
) n.Status;

pub extern fn napi_create_string_utf8(
    env: t.Env,
    str_ptr: [*]const u8,
    str_len: usize,
    js_str: *?t.Val,
) n.Status;

pub extern fn napi_get_value_string_latin1(
    env: t.Env,
    val: t.Val,
    buf_ptr: ?[*]u8,
    buf_len: usize,
    chars_written: *usize,
) n.Status;

pub extern fn napi_get_value_string_utf16(
    env: t.Env,
    val: t.Val,
    buf_ptr: ?[*]u16,
    buf_len: usize,
    chars_written: *usize,
) n.Status;

pub extern fn napi_get_value_string_utf8(
    env: t.Env,
    val: t.Val,
    buf_ptr: ?[*]u8,
    buf_len: usize,
    chars_written: *usize,
) n.Status;

pub extern fn node_api_create_external_string_latin1(
    env: t.Env,
    str: [*:0]const u8,
    length: usize,
    finalize_callback: ?n.FinalizeCb,
    finalize_hint: ?t.AnyPtrConst,
    val_str: *?t.Val,
    copied: *bool,
) n.Status;

pub extern fn node_api_create_external_string_utf16(
    env: t.Env,
    str: [*:0]const u16,
    length: usize,
    finalize_callback: ?n.FinalizeCb,
    finalize_hint: ?t.AnyPtrConst,
    res: *?t.Val,
    copied: *bool,
) n.Status;
