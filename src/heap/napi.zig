const n = @import("../napi.zig");
const t = @import("../root.zig");

pub const cleanup = struct {
    pub const AsyncHook = *const opaque {};
    pub const Cb = *const fn (?t.AnyPtr) callconv(.c) void;
    pub const CbAsync = *const fn (AsyncHook, ?t.AnyPtr) callconv(.c) void;
};

pub const FinalizeCb = *const fn (
    env: t.Env,
    data: ?t.AnyPtr,
    hint: ?t.AnyPtr,
) callconv(.c) void;

pub extern fn napi_add_async_cleanup_hook(
    env: t.Env,
    hook: cleanup.CbAsync,
    arg: ?t.AnyPtrConst,
    out_hook: ?*?cleanup.AsyncHook,
) n.Status;

pub extern fn napi_add_env_cleanup_hook(
    env: t.Env,
    fun: cleanup.Cb,
    arg: ?t.AnyPtrConst,
) n.Status;

pub extern fn napi_adjust_external_memory(
    env: t.Env,
    change_in_bytes: i64,
    adjusted_value: *i64,
) n.Status;

pub extern fn napi_create_external(
    env: t.Env,
    data: t.AnyPtrConst,
    finalize_cb: ?FinalizeCb,
    finalize_hint: ?t.AnyPtrConst,
    out_val: *?t.Val,
) n.Status;

pub extern fn napi_get_instance_data(env: t.Env, data: *?t.AnyPtr) n.Status;

pub extern fn napi_get_value_external(
    env: t.Env,
    val: ?t.Val,
    out_val: *?t.AnyPtr,
) n.Status;

pub extern fn napi_remove_async_cleanup_hook(hook: cleanup.AsyncHook) n.Status;

pub extern fn napi_remove_env_cleanup_hook(
    env: t.Env,
    fun: cleanup.Cb,
    arg: ?t.AnyPtrConst,
) n.Status;

pub extern fn napi_set_instance_data(
    env: t.Env,
    data: t.AnyPtrConst,
    finalize_cb: ?FinalizeCb,
    finalize_hint: ?t.AnyPtrConst,
) n.Status;
