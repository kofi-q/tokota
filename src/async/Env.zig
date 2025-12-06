//! `Env` API methods for asynchronous operations.

const std = @import("std");

const async = @import("../root.zig").async;
const Deferred = @import("promise.zig").Deferred;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Promise = @import("promise.zig").Promise;
const tsfn = @import("threadsafe_fn.zig");
const Val = @import("../root.zig").Val;
const wrapComplete = @import("worker.zig").wrapComplete;
const wrapCompleteT = @import("worker.zig").wrapCompleteT;
const wrapExecute = @import("worker.zig").wrapExecute;
const wrapExecuteT = @import("worker.zig").wrapExecuteT;

/// Schedules a task to be run in a NodeJS worker thread. Returns a JS `Promise`
/// that is settled when the task completes.
///
/// `executor_ptr` is a pointer to a Zig struct instance containing the
/// following methods:
///
/// #### execute `[ Required ]`
/// ```zig
/// pub fn execute(@TypeOf(executor_ptr)) anyerror!T;
/// ```
/// Runs on a worker thread. Called with `executor_ptr` as the sole argument and
/// can return any value and/or error. Return values are forwarded to the
/// optional `complete()` method on the main thread - if no `complete()` method
/// is specified, the `Promise` is resolved with the return value of
/// `execute()`, converted to a corresponding JS value, if supported. Errors
/// returned here will cause the promise to be rejected. Rejection values can
/// be customised via an `errConvert` method (see below).
///
/// #### complete `[ Optional ]`
/// ```zig
/// pub fn complete(@TypeOf(executor_ptr), Env, T) anyerror!R;
/// ```
/// Runs on the main JS thread after `execute()`. Called with `executor_ptr` as
/// the first argument and the return value of `execute()` as the last argument,
/// enabling optional conversion of the result of `execute` to a more
/// appropriate type for JS. A returned value will be used to resolve the JS
/// `Promise`. If non-`Val`, the return value will first be converted to a
/// corresponding JS `Val`, if supported.
/// Errors returned here will cause the promise to be rejected. Rejection
/// values can be customised via an `errConvert` method (see below).
///
/// #### errConvert `[ Optional ]`
/// ```zig
/// pub fn errConvert(@TypeOf(executor_ptr), Env, anyerror) anyerror!void;
/// ```
/// Runs on the main JS thread after `complete()` or `execute()`, whichever
/// returns an error first. Called with `executor_ptr` as the first argument and
/// the error from `complete()` or `execute()` as the last argument, enabling
/// optional conversion of the error to a JS `Val`, or a value that can be
/// converted to `Val`. The `Promise` is then rejected with the return value.
/// If another Zig `error` is returned, the promise is rejected with a JS
/// `Error` with a code field set to the error name.
///
///
/// #### cleanUp `[ Optional ]`
/// ```zig
/// pub fn cleanUp(@TypeOf(executor_ptr), Env) anyerror!void;
/// ```
/// Runs on the main JS thread after all other executor methods have run and
/// after the `Promise` is settled, but *before* execution is returned to JS.
/// Called with `executor_ptr` as the first argument, enabling optional cleanup
/// of the async task, if needed.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const std = @import("std");
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// var generator: Generator = undefined;
///
/// pub fn randomBytes(call: t.Call, len: u8) !t.Promise {
///     generator = .{
///         .buf = undefined,
///         .len = len,
///         .task = undefined,
///     };
///
///     return call.env.asyncTask(&generator, &generator.task);
/// }
///
/// const Generator = struct {
///     buf: [255]u8,
///     len: u8,
///     task: t.async.Task(*@This()),
///
///     pub fn execute(self: *Generator) ![]u8 {
///         if (self.len < 64) return error.NeedMoreBytes;
///
///         const buf = self.buf[0..self.len];
///         try std.posix.getrandom(buf);
///
///         return buf;
///     }
///
///     pub fn complete(_: *Generator, env: t.Env, bytes: []u8) !t.TypedArray(.u8) {
///         // JS value allocation can only happen on the main thread, so this
///         // conversion is done in the `complete()` method, which is called
///         // from the main thread.
///         return env.typedArrayFrom(bytes);
///     }
///
///     pub fn errConvert(_: *Generator, env: t.Env, err: anyerror) !t.Val {
///         return switch (err) {
///             error.NeedMoreBytes => env.err("More bytes, please!", err),
///             else => env.err("Something went wrong.", err),
///         };
///     }
/// };
/// ```
///
/// ```js
/// // main.js
///
/// const addon = require("./addon.node");
///
/// addon
///   .randomBytes(255)
///   .then(bytes => console.log("resolved:", bytes))
///   .catch(err => console.error("rejected:", err));
/// ```
///
/// More examples available in:
/// - [./examples/async](https://github.com/kofi-q/tokota/blob/main/examples/main.zig)
/// - [./src/async/test.zig](https://github.com/kofi-q/tokota/blob/main/src/async/test.zig)
///
/// Refs:
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_async_work
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_promise
pub fn asyncTask(
    self: Env,
    executor_ptr: anytype,
    task: *async.Task(@TypeOf(executor_ptr)),
) !Promise {
    const Task = async.Task(@TypeOf(executor_ptr));

    const prom, const deferred = try self.promise();

    var async_work: ?async.Worker = undefined;
    try n.napi_create_async_work(
        self,
        prom.ptr,
        try async.Resource.default.nameVal(self),
        @ptrCast(&Task.execute),
        @ptrCast(&Task.complete),
        task,
        &async_work,
    ).check();

    task.* = .{
        .deferred = deferred,
        .executor = executor_ptr,
        .work = async_work.?,
    };
    errdefer task.work.delete(self) catch |err| self.throwOrPanic(.{
        .code = @errorName(err),
        .msg = "Async task cleanup failed",
    });

    try task.work.schedule(self);

    return prom;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_async_work
pub fn asyncWorker(
    self: Env,
    comptime execute: async.Execute,
    comptime complete: async.Complete,
    resource: ?async.Resource,
) !async.Worker {
    const async_resource = resource orelse async.Resource.default;
    var ptr: ?async.Worker = null;
    try n.napi_create_async_work(
        self,
        async_resource.ptr,
        try async_resource.nameVal(self),
        wrapExecute(execute),
        wrapComplete(complete),
        null,
        &ptr,
    ).check();

    return ptr.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_async_work
pub fn asyncWorkerT(
    self: Env,
    ctx: anytype,
    comptime execute: async.ExecuteT(@TypeOf(ctx)),
    comptime complete: async.CompleteT(@TypeOf(ctx)),
    resource: ?async.Resource,
) !async.Worker {
    const T = @TypeOf(ctx);
    const async_resource = resource orelse async.Resource.default;

    var ptr: ?async.Worker = null;
    try n.napi_create_async_work(
        self,
        async_resource.ptr,
        try async_resource.nameVal(self),
        wrapExecuteT(T, execute),
        wrapCompleteT(T, complete),
        ctx,
        &ptr,
    ).check();

    return ptr.?;
}

/// Creates a new JS [Promise](https://mdn.io/Promise), along with a `Deferred`
/// resolver. The `Promise` is typically returned to JS, where it can be
/// awaited. Resolving or rejecting the `Deferred` will settle the JS `Promise`
/// accordingly.
///
/// ## Example
///
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn doSomethingAsync(call: t.Call) !t.Promise {
///     const promise, const deferred = try call.env.promise();
///
///     // This should eventually call `deferred.resolve()` or
///     // `deferred.reject()` on the main thread.
///     scheduleTask(deferred);
///
///     // Return the `Promise` to JS, where it can be awaited.
///     return promise;
/// }
/// ```
///
/// The above is equivalent to the following in JS:
/// ```js
/// export function doSomethingAsync() {
///     const { promise ...deferred } = Promise.withResolvers();
///
///     scheduleTask(deferred);
///
///     return promise;
/// }
/// ```
///
/// > #### ⚠ NOTE
/// > `Deferred` methods must be invoked on the main thread. See
/// `asyncTask()` for examples for convenience wrappers around `Promise`s and
/// Node async workers.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_promise
pub fn promise(self: Env) !(struct { Promise, Deferred }) {
    var ptr: ?Val = null;
    var deferred: ?Deferred = null;
    try n.napi_create_promise(self, &deferred, &ptr).check();

    return .{
        Promise{ .env = self, .ptr = ptr.? },
        deferred.?,
    };
}

/// Returns an immediately rejected JS [Promise](https://mdn.io/Promise).
///
/// Equivalent to the following in JS:
/// ```js
/// Promise.reject(err);
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_promise
pub fn promiseReject(self: Env, err: anytype) !Promise {
    const prom, const deferred = try self.promise();
    try deferred.reject(self, err);

    return prom;
}

/// Returns an immediately resolved JS [Promise](https://mdn.io/Promise).
///
/// Equivalent to the following in JS:
/// ```js
/// Promise.resolve(val);
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_promise
pub fn promiseResolve(self: Env, val: anytype) !Promise {
    const prom, const deferred = try self.promise();
    try deferred.resolve(self, val);

    return prom;
}

/// Creates a Node-API `thread-safe function`, which enables communication
/// between background/worker threads and the main JS thread. The given function
/// will be invoked on the main thread when the threadsafe function is called,
/// allowing calls to be made into JS if necessary.
///
/// Common use cases would be invoking a JS callback (or settling a `Promise`)
/// after a long-running asynchronous operation, or emitting events from a
/// background thread.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const std = @import("std");
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn makePromise(call: t.Call) !t.Promise {
///     const promise, const deferred = try call.env.promise();
///     const on_done =
///         try call.env.threadsafeFn(deferred, [*:0]const u8, complete, .{});
///
///     const thread = try std.Thread.spawn(.{}, execute, .{on_done});
///     thread.detach();
///
///     return promise;
/// }
///
/// const OnDoneFn = t.threadsafe.FnT(t.Deferred, [*:0]const u8);
///
/// fn execute(on_done: OnDoneFn) void {
///     defer on_done.release(.release) catch |err| t.panic(
///         "unable to release threadsafe fn",
///         @errorName(err),
///     );
///
///     std.Thread.sleep(std.time.ns_per_s * 2);
///
///     on_done.call("I promise.", .blocking) catch |err| switch (err) {
///         t.Err.ThreadsafeFnClosing => {},
///         else => t.panic("unable to call threadsafe fn", @errorName(err)),
///     };
/// }
///
/// fn complete(deferred: t.Deferred, env: t.Env, msg: [*:0]const u8) !void {
///     try deferred.resolve(env, msg);
/// }
/// ```
///
/// ```js
/// // main.js
///
/// const addon = require("./addon.node");
///
/// addon
///   .makePromise()
///   .then(response => console.log(response))
///   .catch(err => console.error(err));
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_threadsafe_function
pub fn threadsafeFn(
    self: Env,
    ctx: anytype,
    comptime Arg: type,
    comptime handler: tsfn.Callback(@TypeOf(ctx), Arg),
    config: tsfn.Config,
) !tsfn.FnT(@TypeOf(ctx), Arg) {
    var ptr: ?tsfn.FnT(@TypeOf(ctx), Arg) = null;

    try n.napi_create_threadsafe_function(
        self,
        null, // JS callback
        config.resource.ptr,
        try config.resource.nameVal(self),
        config.max_queue_size,
        config.initial_thread_count,
        config.finalizer.data,
        config.finalizer.cb,
        switch (@TypeOf(ctx)) {
            void => null,
            else => ctx,
        },
        tsfn.wrapCallback(@TypeOf(ctx), Arg, handler),
        @ptrCast(&ptr),
    ).check();

    return ptr.?;
}
