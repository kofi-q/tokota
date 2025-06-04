const std = @import("std");

const AnyPtr = @import("../root.zig").AnyPtr;
const Env = @import("../root.zig").Env;
const Err = @import("../root.zig").Err;
const log = @import("../root.zig").log;
const n = @import("../napi.zig");
const options = @import("../root.zig").options;

/// https://nodejs.org/docs/latest/api/n-api.html#simple-asynchronous-operations
pub const Worker = *const NapiWorker;
const NapiWorker = opaque {
    /// Cancels queued work if it has not yet been started. If it has already
    /// started executing, `Err.GenericFailure` will be returned. If
    /// successful, the registered 'complete' callback will be invoked with an
    /// `Err.AsyncWorkCancelled` argument.
    ///
    /// > #### ⚠ NOTE
    /// > The work should not be deleted before the complete callback
    /// invocation, even if it has been successfully cancelled.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_cancel_async_work
    pub fn cancel(self: Worker, env: Env) !void {
        try n.napi_cancel_async_work(env, self).check();
    }

    /// De-allocates the async work and renders it unusable.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_delete_async_work
    pub fn delete(self: Worker, env: Env) !void {
        try n.napi_delete_async_work(env, self).check();
    }

    /// Schedules this work for execution on the event queue.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_queue_async_work
    pub fn schedule(self: Worker, env: Env) !void {
        n.napi_queue_async_work(env, self).check() catch |err| {
            self.cancel(env) catch |err_cancel| log.err(
                "[{}] Unable to cancel async work " ++
                    "after scheduling failure.",
                .{err_cancel},
            );

            return err;
        };
    }
};

/// https://nodejs.org/docs/latest/api/n-api.html#napi_async_complete_callback
pub const Complete = fn (Env, Err!void) anyerror!void;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_async_complete_callback
pub fn CompleteT(comptime Ctx: type) type {
    return fn (Ctx, Env, Err!void) anyerror!void;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_async_execute_callback
pub const Execute = fn () anyerror!void;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_async_execute_callback
pub fn ExecuteT(comptime Ctx: type) type {
    return fn (Ctx) anyerror!void;
}

pub fn wrapExecute(comptime func: Execute) n.AsyncExecute {
    const Cb = struct {
        fn proxy(env: Env, _: ?AnyPtr) callconv(.C) void {
            func() catch |err| switch (err) {
                Err.PendingException => {},
                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.comptimePrint(
                        "[ {s}:async:worker ] Task execution failed",
                        .{options.lib_name},
                    ),
                }),
            };
        }
    };

    return @ptrCast(&Cb.proxy);
}

pub fn wrapExecuteT(
    comptime Ctx: type,
    comptime func: ExecuteT(Ctx),
) n.AsyncExecute {
    const Cb = struct {
        fn proxy(env: Env, ctx: ?Ctx) callconv(.C) void {
            @call(.always_inline, func, .{ctx.?}) catch |err| switch (err) {
                Err.PendingException => {},
                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.comptimePrint(
                        "[ {s}:async:worker:{s} ] Task execution failed",
                        .{ @typeName(Ctx), options.lib_name },
                        .{options.lib_name},
                    ),
                }),
            };
        }
    };

    return @ptrCast(&Cb.proxy);
}

pub fn wrapComplete(comptime func: Complete) n.AsyncComplete {
    const Cb = struct {
        fn proxy(env: Env, status: n.Status, _: ?AnyPtr) callconv(.C) void {
            @call(.always_inline, func, .{
                env, status.check(),
            }) catch |err| switch (err) {
                Err.PendingException => {},
                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.comptimePrint(
                        "[ {s}:async:worker ] Task completion failed",
                        .{options.lib_name},
                    ),
                }),
            };
        }
    };

    return @ptrCast(&Cb.proxy);
}

pub fn wrapCompleteT(
    comptime Ctx: type,
    comptime func: CompleteT(Ctx),
) n.AsyncComplete {
    const Cb = struct {
        fn proxy(env: Env, status: n.Status, ctx: ?Ctx) callconv(.C) void {
            @call(.always_inline, func, .{
                ctx.?, env, status.check(),
            }) catch |err| switch (err) {
                Err.PendingException => {},
                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.comptimePrint(
                        "[ {s}:async:worker:{s} ] Task completion failed",
                        .{ @typeName(Ctx), options.lib_name },
                    ),
                }),
            };
        }
    };

    return @ptrCast(&Cb.proxy);
}
