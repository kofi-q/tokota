const n = @import("../napi.zig");
const t = @import("../root.zig");
const tsfn = @import("threadsafe_fn.zig");
const work = @import("worker.zig");

/// https://nodejs.org/docs/latest/api/n-api.html#napi_async_complete_callback
pub const AsyncComplete = *const fn (
    t.Env,
    n.Status,
    ?t.AnyPtr,
) callconv(.c) void;

pub const AsyncContext = *const opaque {};

/// https://nodejs.org/docs/latest/api/n-api.html#napi_async_execute_callback
pub const AsyncExecute = *const fn (t.Env, ?t.AnyPtr) callconv(.c) void;

pub const AsyncWorker = t.async.Worker;

pub const CallbackScope = *const opaque {};

pub const ThreadsafeFn = tsfn.FnT(t.AnyPtr, t.AnyPtr);

/// Native handler for Threadsafe Function calls, invoked on the main thread and
/// intended as a proxy for calling into JS with an appropriately translated
/// result (e.g. by calling a JS function, or resolving a `Promise`).
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_threadsafe_function_call_js
pub const ThreadsafeFnProxy = *const fn (
    env: t.Env,
    func: t.Val,
    ctx: t.AnyPtrConst,
    data: ?t.AnyPtr,
) callconv(.c) void;

pub extern fn napi_acquire_threadsafe_function(func: ThreadsafeFn) n.Status;

pub extern fn napi_async_destroy(env: t.Env, context: AsyncContext) n.Status;

pub extern fn napi_async_init(
    env: t.Env,
    resource: t.Val,
    resource_name: t.Val,
    result: *?AsyncContext,
) n.Status;

pub extern fn napi_call_threadsafe_function(
    func: ThreadsafeFn,
    data: ?t.AnyPtrConst,
    is_blocking: tsfn.CallMode,
) n.Status;

pub extern fn napi_cancel_async_work(env: t.Env, work: AsyncWorker) n.Status;

pub extern fn napi_close_callback_scope(
    env: t.Env,
    scope: CallbackScope,
) n.Status;

pub extern fn napi_create_async_work(
    env: t.Env,
    async_resource: ?t.Val,
    async_resource_name: t.Val,
    execute: AsyncExecute,
    complete: AsyncComplete,
    data: ?t.AnyPtrConst,
    result: *?AsyncWorker,
) n.Status;

pub extern fn napi_create_promise(
    env: t.Env,
    deferred: *?t.Deferred,
    promise: *?t.Val,
) n.Status;

pub extern fn napi_create_threadsafe_function(
    env: t.Env,
    func: ?t.Val,
    async_resource: ?t.Val,
    async_resource_name: t.Val,
    max_queue_size: usize,
    initial_thread_count: usize,
    thread_finalize_data: ?t.AnyPtrConst,
    thread_finalize_cb: ?n.FinalizeCb,
    context: ?t.AnyPtrConst,
    call_js_cb: ?ThreadsafeFnProxy,
    result: *?ThreadsafeFn,
) n.Status;

pub extern fn napi_delete_async_work(env: t.Env, work: AsyncWorker) n.Status;

pub extern fn napi_get_threadsafe_function_context(
    func: ThreadsafeFn,
    result: *?t.AnyPtr,
) n.Status;

pub extern fn napi_is_promise(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn napi_make_callback(
    env: t.Env,
    context: AsyncContext,
    this: ?t.Val,
    func: t.Val,
    args_len: usize,
    args_ptr: [*]const t.Val,
    result: *?t.Val,
) n.Status;

pub extern fn napi_open_callback_scope(
    env: t.Env,
    _deprecated: ?t.Val,
    context: AsyncContext,
    out_scope: *?CallbackScope,
) n.Status;

pub extern fn napi_queue_async_work(env: t.Env, work: AsyncWorker) n.Status;

pub extern fn napi_ref_threadsafe_function(
    env: t.Env,
    func: ThreadsafeFn,
) n.Status;

pub extern fn napi_reject_deferred(
    env: t.Env,
    deferred: t.Deferred,
    val: t.Val,
) n.Status;

pub extern fn napi_release_threadsafe_function(
    func: ThreadsafeFn,
    mode: tsfn.ReleaseMode,
) n.Status;

pub extern fn napi_resolve_deferred(
    env: t.Env,
    deferred: t.Deferred,
    val: t.Val,
) n.Status;

pub extern fn napi_unref_threadsafe_function(
    env: t.Env,
    func: ThreadsafeFn,
) n.Status;
