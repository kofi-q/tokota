const std = @import("std");
const builtin = @import("builtin");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModuleWithInit(@This(), moduleInit);
}

fn moduleInit(env: t.Env, exports: t.Val) !t.Val {
    _ = try env.addCleanup({}, moduleDeinit);
    return exports;
}

fn moduleDeinit() !void {
    return switch (dba.deinit()) {
        .ok => {},
        .leak => t.panic("Memory leak detected", null),
    };
}

pub const ThreadsafeFns = struct {
    pub fn callMeBack(cb: t.Fn) !void {
        return TaskCallback.schedule(cb);
    }

    pub fn makePromise(call: t.Call) !t.Promise {
        return TaskPromise.schedule(call.env);
    }
};

const TaskCallback = struct {
    pub fn schedule(cb: t.Fn) !void {
        const tsfn = try cb.threadsafeFn({}, [*:0]const u8, complete, .{
            .max_queue_size = 4,
        });

        const thread = try std.Thread.spawn(.{}, execute, .{tsfn});
        thread.detach();
    }

    fn complete(env: t.Env, msg: [*:0]const u8, cb: t.Fn) !void {
        _ = cb.call(msg) catch |err| return env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "unable to invoke JS callback",
        });
    }

    fn execute(tsfn: t.threadsafe.Fn([*:0]const u8)) !void {
        defer tsfn.release(.release) catch |err| t.panic(
            "unable to release threadsafe fn",
            @errorName(err),
        );

        for ([_][:0]const u8{
            "hey, i just met you",
            "and this is crazy",
            "but, here's my number",
            "so call me, maybe",
        }) |msg| {
            std.Thread.sleep(10 * std.time.ns_per_ms);

            tsfn.call(msg, .non_blocking) catch |err| switch (err) {
                t.Err.ThreadsafeFnClosing => return,
                else => return err,
            };
        }
    }
};

const TaskPromise = struct {
    fn schedule(env: t.Env) !t.Promise {
        const promise, const deferred = try env.promise();
        const tsfn = try env
            .threadsafeFn(deferred, [*:0]const u8, complete, .{});

        const thread = try std.Thread.spawn(.{}, execute, .{tsfn});
        thread.detach();

        return promise;
    }

    fn complete(deferred: t.Deferred, env: t.Env, msg: [*:0]const u8) !void {
        try deferred.resolve(env, msg);
    }

    fn execute(tsfn: t.threadsafe.FnT(t.Deferred, [*:0]const u8)) !void {
        defer tsfn.release(.release) catch |err| t.panic(
            "unable to release threadsafe fn",
            @errorName(err),
        );

        std.Thread.sleep(10 * std.time.ns_per_ms);

        const msg = "I promise.";
        tsfn.call(msg, .blocking) catch |err| switch (err) {
            t.Err.ThreadsafeFnClosing => {},
            else => return err,
        };
    }
};

pub const AsyncWorker = struct {
    deferred: t.Deferred,
    input: [:0]u8,
    work: t.async.Worker,

    fn deinit(self: *AsyncWorker, env: t.Env) void {
        const allo = dba.allocator();
        defer allo.destroy(self);
        defer allo.free(self.input);

        self.work.delete(env) catch |err| env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete async work",
        });
    }

    pub fn resolvingPromise(call: t.Call, input: t.Val) !t.Promise {
        return workIt(call.env, input, reverseIt, resolveIt);
    }

    pub fn rejectingPromise(call: t.Call, input: t.Val) !t.Promise {
        return workIt(call.env, input, ignoreIt, rejectIt);
    }

    fn workIt(
        env: t.Env,
        input: t.Val,
        comptime execute_it: t.async.ExecuteT(*AsyncWorker),
        comptime complete_it: t.async.CompleteT(*AsyncWorker),
    ) !t.Promise {
        const promise, const deferred = try env.promise();

        const allo = dba.allocator();
        const task = try allo.create(AsyncWorker);
        task.* = .{
            .input = try input.stringAlloc(env, allo),
            .deferred = deferred,
            .work = try env.asyncWorkerT(task, execute_it, complete_it, .{
                .name = "[tokota-tests]: work-it",
            }),
        };
        errdefer task.deinit(env);

        try task.work.schedule(env);

        return promise;
    }

    fn reverseIt(self: *AsyncWorker) !void {
        std.Thread.sleep(10 * std.time.ns_per_ms);
        std.mem.reverse(u8, self.input);
    }

    fn resolveIt(self: *AsyncWorker, env: t.Env, err: anyerror!void) !void {
        defer self.deinit(env);

        try err;
        try self.deferred.resolve(env, self.input);
    }

    fn ignoreIt(_: *AsyncWorker) !void {
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }

    fn rejectIt(self: *AsyncWorker, env: t.Env, err: anyerror!void) !void {
        defer self.deinit(env);

        try err;
        try self.deferred.reject(env, try env.err("daabi da", {}));
    }
};

pub const Promises = struct {
    const chaining_handlers = struct {
        pub fn ok(result: u32) bool {
            return result > 9000;
        }

        const Call = t.CallT(t.Ref(t.Fn));

        pub fn err(call: Call, msg: t.TinyStr(32)) !void {
            var buf: [64]u8 = undefined;

            const err_new = try call.env.err(
                try std.fmt.bufPrint(&buf, "[modified] {f}", .{msg}),
                {},
            );

            return call.env.throw(err_new);
        }

        pub fn finally(call: Call) !void {
            const on_done_ref = try call.data() orelse {
                return error.MissingCallData;
            };

            const on_done = try on_done_ref.val(call.env) orelse {
                return error.MissingReferenceValue;
            };

            _ = try on_done.call("done");
            _ = try on_done_ref.unref(call.env);
        }
    };

    pub fn chain(promise: t.Promise, on_done: t.Fn) !t.Promise {
        const on_done_ref = try on_done.ref(1);
        return promise.then(on_done_ref, chaining_handlers);
    }

    pub fn chainOkOnly(promise: t.Promise) !t.Promise {
        return promise.then({}, struct {
            pub fn ok(result: u32) bool {
                return result > 9000;
            }
        });
    }
};

pub const AsyncTask = struct {
    const ExecuteOnly = struct {
        result: f64,
        task: t.async.Task(*@This()),

        fn schedule(self: *ExecuteOnly, env: t.Env, result: f64) !t.Promise {
            self.* = .{ .result = result, .task = undefined };
            return env.asyncTask(self, &self.task);
        }

        pub fn execute(self: *ExecuteOnly) f64 {
            return self.result;
        }
    };

    var task_execute_only: ExecuteOnly = undefined;

    pub fn scheduleExecuteOnly(call: t.Call, result: f64) !t.Promise {
        return task_execute_only.schedule(call.env, result);
    }

    const WithComplete = struct {
        result: f64,
        task: t.async.Task(*@This()),

        fn schedule(self: *WithComplete, env: t.Env, result: f64) !t.Promise {
            self.* = .{ .result = result, .task = undefined };
            return env.asyncTask(self, &self.task);
        }

        pub fn execute(self: *WithComplete) f64 {
            return self.result;
        }

        pub fn complete(_: *WithComplete, _: t.Env, result: f64) ![]const u8 {
            var buf: [8]u8 = undefined;
            return std.fmt.bufPrint(&buf, "{d}", .{result});
        }
    };

    var task_with_complete: WithComplete = undefined;

    pub fn scheduleWithComplete(call: t.Call, result: f64) !t.Promise {
        return task_with_complete.schedule(call.env, result);
    }

    const WithCleanup = struct {
        on_cleanup: t.Ref(t.Fn),
        result: f64,
        task: t.async.Task(*@This()),

        fn schedule(self: *WithCleanup, call: t.Call) !t.Promise {
            const result, const on_cleanup = try call.argsAs(.{ f64, t.Fn });
            self.* = .{
                .result = result,
                .on_cleanup = try on_cleanup.ref(1),
                .task = undefined,
            };

            return call.env.asyncTask(self, &self.task);
        }

        pub fn execute(self: *WithCleanup) f64 {
            return self.result;
        }

        pub fn cleanUp(self: *WithCleanup, env: t.Env) !void {
            const on_cleanup = try self.on_cleanup.val(env) orelse {
                return error.BrokenCleanupCallbackRef;
            };

            _ = try on_cleanup.call(true);
        }
    };

    var task_with_cleanup: WithCleanup = undefined;

    pub fn scheduleWithCleanup(call: t.Call) !t.Promise {
        return task_with_cleanup.schedule(call);
    }

    const WithErrConvert = struct {
        on_cleanup: t.Ref(t.Fn),
        task: t.async.Task(*@This()),

        fn schedule(
            self: *WithErrConvert,
            env: t.Env,
            on_cleanup: t.Fn,
        ) !t.Promise {
            self.* = .{
                .on_cleanup = try on_cleanup.ref(1),
                .task = undefined,
            };
            return env.asyncTask(self, &self.task);
        }

        pub fn execute(_: *WithErrConvert) !void {
            return error.SorryDave;
        }

        pub fn errConvert(
            _: *WithErrConvert,
            _: t.Env,
            err: anyerror,
        ) ![]const u8 {
            return @errorName(err);
        }

        pub fn cleanUp(self: *WithErrConvert, env: t.Env) !void {
            const on_cleanup = try self.on_cleanup.val(env) orelse {
                return error.BrokenCleanupCallbackRef;
            };

            _ = try on_cleanup.call(true);
        }
    };

    var task_with_err_convert: WithErrConvert = undefined;

    pub fn scheduleWithErrConvert(call: t.Call, on_cleanup: t.Fn) !t.Promise {
        return task_with_err_convert.schedule(call.env, on_cleanup);
    }
};
