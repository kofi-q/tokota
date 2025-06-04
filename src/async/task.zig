const std = @import("std");

const Deferred = @import("promise.zig").Deferred;
const Env = @import("../root.zig").Env;
const Err = @import("../root.zig").Err;
const n = @import("../napi.zig");
const options = @import("../root.zig").options;
const Worker = @import("worker.zig").Worker;

/// Handler for async tasks that run on NodeJS worker threads, scheduled via
/// `Env.asyncTask()`.
pub fn Task(comptime ExecutorPtr: type) type {
    const Executor = @typeInfo(ExecutorPtr).pointer.child;

    const ResultOk = FnPayload(Executor.execute);

    const ResultErr = if (@hasDecl(Executor, "errConvert"))
        FnPayload(Executor.errConvert)
    else
        void;

    return struct {
        deferred: Deferred,
        executor: *Executor,
        result: anyerror!ResultOk = error.NotStarted,
        work: Worker,

        const Self = @This();

        pub fn execute(_: Env, ptr: ?*Self) callconv(.c) void {
            const self = ptr.?;
            self.result = @call(.always_inline, Executor.execute, .{
                self.executor,
            });
        }

        pub fn complete(
            env: Env,
            status_node: n.Status,
            ptr: ?*Self,
        ) callconv(.c) void {
            const self = ptr.?;

            const async_work = self.work;
            defer async_work.delete(env) catch |e| env.throwOrPanic(.{
                .code = @errorName(e),
                .msg = std.fmt.comptimePrint(
                    "[ {s} ] Unable to delete async work",
                    .{@typeName(Executor)},
                ),
            });

            defer if (@hasDecl(Executor, "cleanUp")) {
                const result = @call(.always_inline, Executor.cleanUp, .{
                    self.executor, env,
                });

                switch (@typeInfo(@TypeOf(result))) {
                    .error_union => result catch |e| env.throwOrPanic(.{
                        .code = @errorName(e),
                        .msg = std.fmt.comptimePrint(
                            "[ {s} ] Async cleanup failed",
                            .{@typeName(Executor)},
                        ),
                    }),
                    else => {},
                }
            };

            status_node.check() catch |err| switch (err) {
                Err.AsyncWorkCancelled => return,
                else => self.reject(env, err),
            };

            const result = self.result catch |err| {
                return self.reject(env, err);
            };

            self.resolve(env, result) catch |err| self.reject(env, err);
        }

        fn resolve(self: *Self, env: Env, res: ResultOk) !void {
            if (!@hasDecl(Executor, "complete")) {
                return self.deferred.resolve(env, res);
            }

            if (ResultOk == void) return self.deferred.resolve(
                env,
                try @call(.always_inline, Executor.complete, .{
                    self.executor, env,
                }),
            );

            return self.deferred.resolve(
                env,
                try @call(.always_inline, Executor.complete, .{
                    self.executor, env, res,
                }),
            );
        }

        fn reject(self: *Self, env: Env, err: anyerror) void {
            if (err == Err.PendingException) return;

            const err_as_val = self.errConvert(env, err) catch |err_as_code| {
                return self.rejectVal(
                    env,
                    env.err(std.fmt.comptimePrint(
                        "[ {s} ] Async task error",
                        .{@typeName(Executor)},
                    ), err_as_code),
                );
            };

            self.rejectVal(env, err_as_val);
        }

        fn rejectVal(self: *Self, env: Env, val: anytype) void {
            self.deferred.reject(env, val) catch |err| switch (err) {
                Err.PendingException => {},

                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.comptimePrint(
                        "[ {s} ] Promise rejection failed",
                        .{@typeName(Executor)},
                    ),
                }),
            };
        }

        inline fn errConvert(self: *Self, env: Env, err: anyerror) !ResultErr {
            if (!@hasDecl(Executor, "errConvert")) return err;

            return @call(.always_inline, Executor.errConvert, .{
                self.executor, env, err,
            });
        }
    };
}

/// Handler for async tasks that run on NodeJS worker threads, scheduled via
/// `Env.asyncTaskManaged()`.
pub fn TaskManaged(comptime Executor: type, comptime Args: type) type {
    const ResultOk = FnPayload(Executor.execute);

    const ResultErr = if (@hasDecl(Executor, "errConvert"))
        FnPayload(Executor.errConvert)
    else
        void;

    return struct {
        arena: std.heap.ArenaAllocator,
        args: Args,
        deferred: Deferred,
        result: anyerror!ResultOk = error.NotStarted,
        work: Worker,

        const Self = @This();

        pub fn execute(_: Env, ptr: ?*Self) callconv(.c) void {
            const self = ptr.?;
            self.result = @call(
                .always_inline,
                Executor.execute,
                .{&self.arena} ++ self.args,
            );
        }

        pub fn complete(
            env: Env,
            status_node: n.Status,
            ptr: ?*Self,
        ) callconv(.c) void {
            const self = ptr.?;

            const arena = self.arena;
            defer arena.deinit();

            const async_work = self.work;
            defer async_work.delete(env) catch |e| env.throwOrPanic(.{
                .code = @errorName(e),
                .msg = std.fmt.comptimePrint(
                    "[ {s} ] Unable to delete async work",
                    .{@typeName(Executor)},
                ),
            });

            defer if (@hasDecl(Executor, "cleanUp")) {
                const result = @call(.always_inline, Executor.cleanUp, .{env});

                switch (@typeInfo(@TypeOf(result))) {
                    .error_union => result catch |e| env.throwOrPanic(.{
                        .code = @errorName(e),
                        .msg = std.fmt.comptimePrint(
                            "[ {s} ] Async cleanup failed",
                            .{@typeName(Executor)},
                        ),
                    }),
                    else => {},
                }
            };

            status_node.check() catch |err| switch (err) {
                Err.AsyncWorkCancelled => return,
                else => self.reject(env, err),
            };

            const result = self.result catch |err| {
                return self.reject(env, err);
            };

            self.resolve(env, result) catch |err| self.reject(env, err);
        }

        fn resolve(self: *Self, env: Env, res: ResultOk) !void {
            if (!@hasDecl(Executor, "complete")) {
                return self.deferred.resolve(env, res);
            }

            if (ResultOk == void) return self.deferred.resolve(
                env,
                try @call(.always_inline, Executor.complete, .{env}),
            );

            return self.deferred.resolve(
                env,
                try @call(.always_inline, Executor.complete, .{ env, res }),
            );
        }

        fn reject(self: *Self, env: Env, err: anyerror) void {
            if (err == Err.PendingException) return;

            const err_as_val = errConvert(env, err) catch |err_as_code| {
                return self.rejectVal(
                    env,
                    env.err(std.fmt.comptimePrint(
                        "[ {s} ] Async task error",
                        .{@typeName(Executor)},
                    ), err_as_code),
                );
            };

            self.rejectVal(env, err_as_val);
        }

        fn rejectVal(self: *Self, env: Env, val: anytype) void {
            self.deferred.reject(env, val) catch |err| switch (err) {
                Err.PendingException => {},

                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = std.fmt.comptimePrint(
                        "[ {s} ] Promise rejection failed",
                        .{@typeName(Executor)},
                    ),
                }),
            };
        }

        inline fn errConvert(env: Env, err: anyerror) !ResultErr {
            if (!@hasDecl(Executor, "errConvert")) return err;

            return @call(.always_inline, Executor.errConvert, .{ env, err });
        }
    };
}

fn FnPayload(comptime f: anytype) type {
    const ReturnType = @typeInfo(@TypeOf(f)).@"fn".return_type.?;

    return switch (@typeInfo(ReturnType)) {
        .error_union => |error_union| error_union.payload,
        else => ReturnType,
    };
}
