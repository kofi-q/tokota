const n = @import("../napi.zig");
const t = @import("../root.zig");

pub extern fn napi_coerce_to_number(
    env: t.Env,
    val: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_bigint_int64(
    env: t.Env,
    value: i64,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_bigint_uint64(
    env: t.Env,
    value: u64,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_bigint_words(
    env: t.Env,
    sign_bit: c_int,
    word_count: usize,
    words: [*]const u64,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_double(env: t.Env, value: f64, res: *?t.Val) n.Status;

pub extern fn napi_create_int32(env: t.Env, value: i32, res: *?t.Val) n.Status;

pub extern fn napi_create_int64(env: t.Env, value: i64, res: *?t.Val) n.Status;

pub extern fn napi_create_uint32(env: t.Env, value: u32, res: *?t.Val) n.Status;

pub extern fn napi_get_value_bigint_int64(
    env: t.Env,
    val: t.Val,
    result: *i64,
    lossless: *bool,
) n.Status;

pub extern fn napi_get_value_bigint_uint64(
    env: t.Env,
    val: t.Val,
    result: *u64,
    lossless: *bool,
) n.Status;

pub extern fn napi_get_value_bigint_words(
    env: t.Env,
    val: t.Val,
    sign_bit: ?*c_uint,
    word_count: *usize,
    words: ?[*]u64,
) n.Status;

pub extern fn napi_get_value_double(
    env: t.Env,
    val: t.Val,
    result: *f64,
) n.Status;

pub extern fn napi_get_value_int32(
    env: t.Env,
    val: t.Val,
    result: *i32,
) n.Status;

pub extern fn napi_get_value_int64(
    env: t.Env,
    val: t.Val,
    result: *i64,
) n.Status;

pub extern fn napi_get_value_uint32(
    env: t.Env,
    val: t.Val,
    result: *u32,
) n.Status;
