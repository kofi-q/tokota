const n = @import("../napi.zig");
const t = @import("../root.zig");

pub const HandleScope = *const opaque {};
pub const HandleScopeEscapable = *const opaque {};
pub const Ref = t.Ref(t.AnyPtr);

pub extern fn napi_close_escapable_handle_scope(
    env: t.Env,
    scope: HandleScopeEscapable,
) n.Status;

pub extern fn napi_close_handle_scope(
    env: t.Env,
    scope: HandleScope,
) n.Status;

pub extern fn napi_create_reference(
    env: t.Env,
    value: t.Val,
    initial_refcount: u32,
    result: *?Ref,
) n.Status;

pub extern fn napi_delete_reference(env: t.Env, ref: Ref) n.Status;

pub extern fn napi_escape_handle(
    env: t.Env,
    scope: HandleScopeEscapable,
    escapee: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_get_reference_value(
    env: t.Env,
    ref: Ref,
    res: *?t.Val,
) n.Status;

pub extern fn napi_open_escapable_handle_scope(
    env: t.Env,
    result: *?HandleScopeEscapable,
) n.Status;

pub extern fn napi_open_handle_scope(
    env: t.Env,
    result: *?HandleScope,
) n.Status;

pub extern fn napi_reference_ref(env: t.Env, ref: Ref, result: *u32) n.Status;

pub extern fn napi_reference_unref(
    env: t.Env,
    ref: Ref,
    result: *u32,
) n.Status;
