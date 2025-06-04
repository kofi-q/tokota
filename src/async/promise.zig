const std = @import("std");

const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Fn = @import("../root.zig").Fn;
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

/// Represents a JS [Promise](https://mdn.io/Promise) object.
///
/// Can be:
/// - Newly allocated via:
///   - `Env.asyncTask()`
///   - `Env.asyncTaskManaged()`
///   - `Env.promise()`
///   - `Env.promiseReject()`
///   - `Env.promiseResolve()`
/// - Cast from an existing JS value via `Val.promise()`.
/// - Received as an argument in a Node-API callback (see `Promise.then()` for
///   an example).
///
/// https://nodejs.org/docs/latest/api/n-api.html#promises
pub const Promise = struct {
    env: Env,
    ptr: Val,

    /// Creates a `Ref` from which the `Object` can later be extracted, outside
    /// of the function scope within which it was initially created or received.
    ///
    /// > #### ⚠ NOTE
    /// > References prevent a JS value from being garbage collected. A
    /// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
    /// proper disposal.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
    pub fn ref(self: Promise, initial_ref_count: u32) !Ref(Promise) {
        var ptr: ?Ref(Promise) = null;
        try n.napi_create_reference(self.env, self.ptr, initial_ref_count, &ptr)
            .check();

        return ptr.?;
    }

    /// Registers chaining callbacks from `handler` on the `Promise` and returns
    /// the resulting `Promise`, which will resolve with the return value of
    /// `handler.ok()` if successful, or the return value of `handler.err()` if
    /// failed.
    ///
    /// If `method_data` has a non-`void` type, it is bound to the callback
    /// methods and will be available via `CallT.data()` when `CallT` is
    /// received as the first argument.
    ///
    /// If either the `ok` or `err` handler returns an error or throws a JS
    /// error, it will result in a rejected `Promise`.
    ///
    /// ## Example
    /// ```zig
    /// const std = @import("std");
    /// const t = @import("tokota");
    ///
    /// comptime {
    ///     t.exportModule(@This());
    /// }
    ///
    /// const NativeData = struct { limit: u32 };
    /// var native_data = NativeData{ .limit = 9000 };
    ///
    /// pub fn isOverLimit(promise: t.Promise) !t.Promise {
    ///     return promise.then(&native_data, struct {
    ///         pub fn ok(call: t.CallT(*NativeData), result: u32) !bool {
    ///             const data = try call.data() orelse return error.MissingData;
    ///             return result > data.limit;
    ///         }
    ///
    ///         pub fn err(e: struct { message: ?t.TinyStr(64) }) bool {
    ///             std.debug.print("err: {?}\n", .{e.message});
    ///             return false;
    ///         }
    ///
    ///         pub fn finally() void {
    ///             std.debug.print("cleaning up...\n", .{});
    ///         }
    ///     });
    /// }
    /// ```
    ///
    /// The above is equivalent to the following in JS:
    /// ```ts
    /// const native_data = { limit: 9000 };
    ///
    /// export function isOverLimit(promise: Promise): Promise {
    ///   const data = native_data;
    ///
    ///   return promise
    ///       .then(result => {
    ///         return result > data.limit;
    ///       })
    ///       .catch(e => {
    ///           console.log(e.message);
    ///           return false;
    ///       })
    ///       .finally(() => {
    ///           console.log("cleaning up...");
    ///       });
    /// }
    /// ```
    ///
    /// If specified, `cb_data` will be available in the handler callbacks
    /// via `Call.data()`, when `Call` is accepted as a first argument.
    ///
    /// - https://mdn.io/Promise/then
    /// - https://mdn.io/Promise/catch
    /// - https://mdn.io/Promise/finally
    pub fn then(
        self: Promise,
        method_data: anytype,
        comptime handlers: anytype,
    ) !Promise {
        const MethodData = @TypeOf(method_data);

        var ptr = self.ptr;

        if (@hasDecl(handlers, "ok")) {
            const js_fn = try ptr.object(self.env).getT("then", Fn);

            const cb = switch (MethodData) {
                void => self.env.function(handlers.ok),
                else => self.env.functionT(handlers.ok, method_data),
            };

            ptr = try js_fn.callThis(ptr, cb);
        }

        if (@hasDecl(handlers, "err")) {
            const js_fn = try ptr.object(self.env).getT("catch", Fn);

            const cb = switch (MethodData) {
                void => self.env.function(handlers.err),
                else => self.env.functionT(handlers.err, method_data),
            };

            ptr = try js_fn.callThis(ptr, cb);
        }

        if (@hasDecl(handlers, "finally")) {
            const js_fn = try ptr.object(self.env).getT("finally", Fn);

            const cb = switch (MethodData) {
                void => self.env.function(handlers.finally),
                else => self.env.functionT(handlers.finally, method_data),
            };

            ptr = try js_fn.callThis(ptr, cb);
        }

        return .{ .env = self.env, .ptr = ptr };
    }
};

/// Provides hooks for settling a JS [Promise](https://mdn.io/Promise) created
/// via `Env.promise()`.
///
/// > #### ⚠ NOTE
/// > Resolution/rejection should happen on the main thread, once the async task
/// has completed. See `Env.asyncWorker()`, `Env.threadsafeFn()`, and
/// `Fn.threadsafeFn()` for ways to schedule callbacks for execution on the main
/// thread.
///
/// For short-lived, asynchronous tasks, `Env.asyncTask()` or
/// `Env.asyncTaskManaged()` may be convenient for scheduling work on NodeJS
/// worker threads.
///
/// https://nodejs.org/docs/latest/api/n-api.html#promises
pub const Deferred = *const NapiDeferred;
const NapiDeferred = opaque {
    /// [Rejects](https://mdn.io/Promise/reject) the corresponding promise.
    /// Values are inferred with `Env.infer()` and can be any valid JS value, or
    /// a native value from which one can be derived.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_reject_deferred
    pub fn reject(self: Deferred, env: Env, err: anytype) !void {
        try n.napi_reject_deferred(env, self, try env.infer(err)).check();
    }

    /// [Resolves](https://mdn.io/Promise/resolve) the corresponding promise.
    /// Values are inferred with `Env.infer()` and can be any valid JS value, a
    /// native value from which one can be derived, or a `void` value, for
    /// an empty resolution.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_resolve_deferred
    pub fn resolve(self: Deferred, env: Env, result: anytype) !void {
        try n.napi_resolve_deferred(env, self, try env.infer(result)).check();
    }
};
