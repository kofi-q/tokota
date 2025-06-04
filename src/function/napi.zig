const n = @import("../napi.zig");
const t = @import("../root.zig");

/// Function type for native functions which are exposed to JS.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_callback
pub const Callback = *const fn (t.Env, CallInfo) callconv(.c) ?t.Val;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_callback_info
pub const CallInfo = *const opaque {};

/// https://nodejs.org/docs/latest/api/n-api.html#napi_call_function
pub extern fn napi_call_function(
    env: t.Env,
    recv: t.Val,
    func: t.Val,
    args_len: usize,
    args_ptr: [*]const t.Val,
    res: *?t.Val,
) n.Status;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_function
pub extern fn napi_create_function(
    env: t.Env,
    name_ptr: ?[*]const u8,
    name_len: usize,
    cb: Callback,
    data: ?t.AnyPtrConst,
    res: *?t.Val,
) n.Status;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
pub extern fn napi_get_cb_info(
    env: t.Env,
    ctx_handle: CallInfo,
    argc: ?*usize,
    argv: ?[*]t.Val,
    this_ptr: ?*?t.Val,
    data: ?*?t.AnyPtr,
) n.Status;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_new_target
pub extern fn napi_get_new_target(
    env: t.Env,
    cbInfo: CallInfo,
    res: *?t.Val,
) n.Status;
