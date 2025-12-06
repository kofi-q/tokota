const std = @import("std");

const AnyPtr = @import("../root.zig").AnyPtr;
const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const Err = @import("../root.zig").Err;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const options = @import("../root.zig").options;
const Resource = @import("Resource.zig");
const tokota = @import("../root.zig");
const Val = @import("../root.zig").Val;

/// Used with `threadsafe.FnT.call()` to indicate whether the call should
/// block whenever the queue associated with the thread-safe function is full.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_threadsafe_function_call_mode
pub const CallMode = enum(c_int) {
    /// Only adds data to the JS call queue iff the queue has room, otherwise,
    /// `Err.QueueFull` is returned.
    non_blocking = 0,

    /// Blocks until there's room in the JS call queue.
    blocking = 1,
};

/// Used with `threadsafe.FnT.release()` to indicate whether the
/// thread-safe function is to be closed immediately (`.abort`), or merely
/// released (`.release`) and thus available for subsequent use via
/// `threadsafe.FnT.acquire()` and `threadsafe.FnT.call()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_threadsafe_function_release_mode
pub const ReleaseMode = enum(c_int) {
    /// Indicates the current thread is done using the thread-safe function.
    /// The thread-safe function will be garbage collected once the all threads
    /// that previously acquired it have released it.
    release = 0,

    /// Indicates that no threads should make any further calls to the
    /// thread-safe function. After aborting a thread-safe function, any further
    /// calls to `threadsafe.FnT.call()` will return `Err.ThreadsafeFnClosing`.
    abort = 1,
};

/// Configuration for Node-API threadsafe functions.
pub const Config = struct {
    /// Optional function to call when the threadsafe function is destroyed.
    finalizer: Finalizer = .none,

    /// The initial number of acquisitions, i.e. the initial number of threads,
    /// including the main thread, which will be making use of this function.
    ///
    /// Defaults to `1`.
    initial_thread_count: usize = 1,

    /// Maximum size of the threadsafe function call queue.
    ///
    /// Set this to `0` for no limit. For values greater than `0`, threadsafe
    /// function calls will either block until there's room in the queue,when
    /// called with `CallMode.blocking`, or return `Err.QueueFull`, when
    /// called with `CallMode.non_blocking`.
    ///
    /// Defaults to `0`.
    max_queue_size: usize = 0,

    /// Optional object associated with the async work that will be passed to
    /// possible `async_hooks` init hooks[1].
    ///
    /// - [1] https://nodejs.org/docs/latest/api/async_hooks.html#initasyncid-type-triggerasyncid-resource)
    resource: Resource = .{
        .name = "[" ++ options.lib_name ++ "] Threadsafe Function",
    },
};

/// Represents a Node-API `thread-safe function`, which enables communication
/// between background/worker threads and the main JS thread. Created via
/// `Env.threadsafeFn()`, or `Fn.threadsafeFn()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_threadsafe_function
pub fn Fn(comptime Arg: type) type {
    return FnT(void, Arg);
}

/// Represents a Node-API `thread-safe function`, which enables communication
/// between background/worker threads and the main JS thread. Created via
/// `Env.threadsafeFn()`, or `Fn.threadsafeFn()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_threadsafe_function
pub fn FnT(comptime T: type, comptime Arg: type) type {
    const NapiThreadsafeFn = opaque {
        const Self = *const @This();

        /// https://nodejs.org/docs/latest/api/n-api.html#napi_release_threadsafe_function
        pub fn abort(self: Self) !void {
            return n.napi_release_threadsafe_function(
                @ptrCast(self),
                .abort,
            ).check() catch |err| switch (err) {
                Err.ThreadsafeFnClosing => {},
                else => err,
            };
        }

        /// https://nodejs.org/docs/latest/api/n-api.html#napi_acquire_threadsafe_function
        pub fn acquire(self: Self) !void {
            try n.napi_acquire_threadsafe_function(self).check();
        }

        /// https://nodejs.org/docs/latest/api/n-api.html#napi_call_threadsafe_function
        pub fn call(self: Self, arg: Arg, mode: CallMode) !void {
            try n.napi_call_threadsafe_function(@ptrCast(self), switch (Arg) {
                void => @as(?AnyPtrConst, null),
                else => arg,
            }, mode).check();
        }

        /// The context pointer, if any, with which the threadsafe function
        /// was created.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_threadsafe_function_context
        pub fn context(self: Self) !T {
            if (T == void) @compileError(
                "No context associated with this Threadsafe Function",
            );

            var ctx: ?T = null;
            try n.napi_get_threadsafe_function_context(
                @ptrCast(self),
                @ptrCast(&ctx),
            ).check();

            return ctx.?;
        }

        /// https://nodejs.org/docs/latest/api/n-api.html#napi_ref_threadsafe_function
        pub fn ref(self: Self, env: Env) !void {
            try n.napi_ref_threadsafe_function(env, @ptrCast(self)).check();
        }

        /// https://nodejs.org/docs/latest/api/n-api.html#napi_release_threadsafe_function
        pub fn release(self: Self) !void {
            return n.napi_release_threadsafe_function(
                @ptrCast(self),
                .release,
            ).check() catch |err| switch (err) {
                Err.ThreadsafeFnClosing => {},
                else => err,
            };
        }

        /// https://nodejs.org/docs/latest/api/n-api.html#napi_unref_threadsafe_function
        pub fn unref(self: Self, env: Env) !void {
            try n.napi_unref_threadsafe_function(env, @ptrCast(self)).check();
        }
    };

    return NapiThreadsafeFn.Self;
}

pub fn Callback(comptime T: type, comptime Arg: type) type {
    return switch (T) {
        void => fn (Env, Arg) anyerror!void,
        else => fn (T, Env, Arg) anyerror!void,
    };
}

pub fn wrapCallback(
    comptime T: type,
    comptime Arg: type,
    comptime func: Callback(T, Arg),
) n.ThreadsafeFnProxy {
    const Ctx = switch (T) {
        void => ?AnyPtrConst,
        else => T,
    };

    const AbiArg = switch (Arg) {
        void => ?AnyPtrConst,
        else => |A| A,
    };

    const Handler = struct {
        fn cb(opt_env: ?Env, _: ?Val, ctx: Ctx, arg: AbiArg) callconv(.c) void {
            // This is null if the Node env is in the process of getting
            // unloaded. If that's the case, nothing to do here.
            const env = opt_env orelse return;

            var buf_err: [128]u8 = undefined;

            const tsfn_arg = switch (Arg) {
                void => {},
                else => arg,
            };

            const cb_args = switch (T) {
                void => .{ env, tsfn_arg },
                else => .{ ctx, env, tsfn_arg },
            };
            @call(.always_inline, func, cb_args) catch |err| switch (err) {
                Err.PendingException => {},

                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.bufPrintZ(
                        &buf_err,
                        "[ {t} ] Error in Threadsafe Function handler - {s}",
                        .{ err, @typeName(T) },
                    ) catch unreachable,
                }),
            };
        }
    };

    return @ptrCast(&Handler.cb);
}

pub fn Proxy(comptime T: type, comptime Arg: type) type {
    return switch (T) {
        void => fn (Env, Arg, tokota.Fn) anyerror!void,
        else => fn (T, Env, Arg, tokota.Fn) anyerror!void,
    };
}

pub fn wrapProxy(
    comptime T: type,
    comptime Arg: type,
    comptime func: Proxy(T, Arg),
) n.ThreadsafeFnProxy {
    const Ctx = switch (T) {
        void => ?AnyPtrConst,
        else => T,
    };

    const AbiArg = switch (Arg) {
        void => ?AnyPtrConst,
        else => |A| A,
    };

    const Handler = struct {
        fn cb(
            env_opt: ?Env,
            cb_js_opt: ?Val,
            ctx: Ctx,
            arg: AbiArg,
        ) callconv(.c) void {
            // These are null if the Node env is in the process of getting
            // unloaded. If that's the case, nothing to do here.
            const env = env_opt orelse return;
            const cb_js = cb_js_opt.?.function(env);

            var buf_err: [128]u8 = undefined;

            const tsfn_arg = switch (Arg) {
                void => {},
                else => arg,
            };

            const args = switch (T) {
                void => .{ env, tsfn_arg, cb_js },
                else => .{ ctx, env, tsfn_arg, cb_js },
            };
            @call(.always_inline, func, args) catch |err| switch (err) {
                Err.PendingException => {},

                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.bufPrintZ(
                        &buf_err,
                        "[ {t} ] Error in Threadsafe Function handler - {s}",
                        .{ err, @typeName(T) },
                    ) catch unreachable,
                }),
            };
        }
    };

    return @ptrCast(&Handler.cb);
}
