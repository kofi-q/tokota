//! Async extensions for `tokota.Fn`.

const Env = @import("../root.zig").Env;
const Fn = @import("../root.zig").Fn;
const n = @import("../napi.zig");
const tsfn = @import("threadsafe_fn.zig");

/// Creates a Node-API `thread-safe function`, which enables communication
/// between background/worker threads and the main JS thread. The native `proxy`
/// function will be invoked on the main thread when the threadsafe function is
/// called, allowing calls to be made to this JS function as needed.
///
/// Common use cases would be invoking a JS callback after a long-running
/// asynchronous operation, or emitting events from a background thread.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_threadsafe_function
pub fn threadsafeFn(
    self: Fn,
    ctx: anytype,
    comptime Arg: type,
    comptime proxy: tsfn.Proxy(@TypeOf(ctx), Arg),
    config: tsfn.Config,
) !tsfn.FnT(@TypeOf(ctx), Arg) {
    var ptr: ?tsfn.FnT(@TypeOf(ctx), Arg) = null;

    try n.napi_create_threadsafe_function(
        self.env,
        self.ptr,
        config.resource.ptr orelse self.ptr,
        try config.resource.nameVal(self.env),
        config.max_queue_size,
        config.initial_thread_count,
        config.finalizer.data,
        config.finalizer.cb,
        switch (@TypeOf(ctx)) {
            void => null,
            else => ctx,
        },
        tsfn.wrapProxy(@TypeOf(ctx), Arg, proxy),
        @ptrCast(&ptr),
    ).check();

    return ptr.?;
}
