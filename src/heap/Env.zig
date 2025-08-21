//! `Env` API methods for managing heap-allocated native values.

const AnyPtr = @import("../root.zig").AnyPtr;
const Cleanup = @import("cleanup.zig").Cleanup;
const CleanupAsync = @import("cleanup.zig").CleanupAsync;
const Err = @import("../root.zig").Err;
const Env = @import("../root.zig").Env;
const Finalizer = @import("Finalizer.zig");
const Object = @import("../root.zig").Object;
const log = @import("../root.zig").log;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// Registers cleanup task to run once the current NodeJS environment exits.
/// The same callback function can safely be specified multiple times with
/// different `ctx` args, in which case, it will be called multiple times.
///
/// Cleanup hooks can be removed by calling `Cleanup.remove()` with the same
/// callback/arg pair. Useful when tearing down the relevant data before the
/// environment exits.
///
/// Cleanup hooks will be called in reverse order, similar to `defer`.
///
/// > #### ⚠ NOTE
/// > Registering the same `callback`/`ctx` pair multiple times will cause the
/// process to abort.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_add_env_cleanup_hook
pub fn addCleanup(
    self: Env,
    ctx: anytype,
    comptime callback: Cleanup.Handler(@TypeOf(ctx)),
) !Cleanup {
    const Ctx = @TypeOf(ctx);
    const cleanup = Cleanup{
        .cb = cleanupProxy(Ctx, callback),
        .ctx = switch (Ctx) {
            void => null,
            else => ctx,
        },
    };

    try n.napi_add_env_cleanup_hook(self, cleanup.cb, cleanup.ctx).check();

    return cleanup;
}

/// Registers cleanup task to run once the current NodeJS environment exits.
/// The same callback function can safely be specified multiple times with
/// different `ctx` args, in which case, it will be called multiple times.
///
/// Unlike `addCleanup()`, the provided callback can be asynchronous.
///
/// Cleanup hooks will be called in reverse order, similar to `defer`.
///
/// > #### ⚠ NOTE
/// > Registering the same `callback`/`ctx` pair multiple times will cause the
/// process to abort.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_add_async_cleanup_hook
pub fn addCleanupAsync(
    self: Env,
    ctx: anytype,
    comptime callback: CleanupAsync.Handler(@TypeOf(ctx)),
) !void {
    const Ctx = @TypeOf(ctx);

    try n.napi_add_async_cleanup_hook(
        self,
        cleanupAsyncProxy(Ctx, callback),
        switch (Ctx) {
            void => null,
            else => ctx,
        },
        null,
    ).check();
}

/// Identical to `addCleanupAsync()`, but additionally returns a handle to
/// the cleanup hook, which can be used to de-register the hook and prevent
/// it from being run run by calling `CleanupCbAsyncHandle.remove()`.
/// Useful when the relevant data maybe be torn down before the
/// environment exits.
pub fn addCleanupAsyncRemovable(
    self: Env,
    ctx: anytype,
    comptime callback: CleanupAsync.Handler(@TypeOf(ctx)),
) !CleanupAsync {
    const Ctx = @TypeOf(ctx);
    var hook: ?n.cleanup.AsyncHook = null;

    try n.napi_add_async_cleanup_hook(
        self,
        cleanupAsyncProxy(Ctx, callback),
        switch (Ctx) {
            void => null,
            else => ctx,
        },
        &hook,
    ).check();

    return .{ .hook = hook.? };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_adjust_external_memory
pub fn adjustOwnedMem(self: Env, delta_bytes: i64) !i64 {
    var res: i64 = undefined;
    try n.napi_adjust_external_memory(self, delta_bytes, &res).check();

    return res;
}

/// Allocates a new JS value with native data attached to it. This data can
/// later be retrieved from the JS value via `Val.external()`.
///
/// The resulting `Val` is not an object with regular properties and has a
/// `ValType` of `.external` returned from `Val.typeOf()`.
///
/// An external object can be received as a callback argument via `External`.
///
/// > #### ⚠ NOTE
/// > `@TypeOf(data)` must have a `comptime js_tag: t.Object.Tag` field to be eligible
/// for use as an external value. A missing or invalid `js_tag` field will
/// result in a compile error.
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
/// pub fn newClient(call: t.Call, foo: u32) !t.Val {
///     const client = try Client.init(foo);
///     return call.env.external(client, .with(Client.deinit));
/// }
///
/// pub fn clientSend(client: t.External(*Client), req: t.TypedArray(.u8)) !bool {
///     return client.ptr.send(req.data);
/// }
///
/// const Client = struct {
///     comptime js_tag: t.Object.Tag = .{ .lower = 0xcafe, .upper = 0xf00d },
///
///     foo: u32,
///
///     fn init(foo: u32) std.mem.Allocator.Error!*Client {
///         const client = try std.heap.smp_allocator.create(Client);
///         client.* = .{ .foo = foo };
///
///         return client;
///     }
///
///     fn deinit(self: *Client, _: t.Env) !void {
///         std.heap.smp_allocator.destroy(self);
///     }
///
///     fn send(self: *Client, data: []const u8) !bool {
///         _ = self;
///         std.debug.print("Sending {x:0>2}...\n", .{data});
///
///         return true;
///     }
/// };
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const addon = require("./addon.node");
///
/// const client = addon.newClient(42);
///
/// const data = Uint8Array.of(0xca, 0xfe);
/// assert.equal(addon.clientSend(client, data), true);
///
/// const notClient = { foo: 42 };
/// assert.throws(() => addon.clientSend(notClient, data), /NativeObjectExpected/);
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_external
pub fn external(
    self: Env,
    data: anytype,
    finalizer_partial: Finalizer.Partial(@TypeOf(data)),
) !Val {
    var ptr: ?Val = null;
    try n.napi_create_external(
        self,
        data,
        finalizer_partial.finalizer.cb,
        finalizer_partial.finalizer.hint,
        &ptr,
    ).check();

    try Object.tagSet(
        .{ .env = self, .ptr = ptr.? },
        Object.Tag.require(@TypeOf(data)),
    );

    return ptr.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_instance_data
pub fn instanceData(self: Env, comptime T: type) !?T {
    var data: ?T = null;
    try n.napi_get_instance_data(self, @ptrCast(&data)).check();

    return data;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_set_instance_data
pub fn instanceDataSet(
    self: Env,
    data: anytype,
    finalizer_partial: Finalizer.Partial(@TypeOf(data)),
) !void {
    try n.napi_set_instance_data(
        self,
        data,
        finalizer_partial.finalizer.cb,
        finalizer_partial.finalizer.hint,
    ).check();
}

fn cleanupProxy(
    comptime Ctx: type,
    comptime cb: Cleanup.Handler(Ctx),
) n.cleanup.Cb {
    const _Ctx = if (Ctx == void) AnyPtr else Ctx;

    return @ptrCast(&struct {
        pub fn proxy(ctx: _Ctx) callconv(.c) void {
            const args = switch (Ctx) {
                void => .{},
                else => .{ctx},
            };

            @call(.always_inline, cb, args) catch |err| switch (Ctx) {
                void => log.err("Cleanup callback failed - {t}", .{err}),
                else => log.err("[ {s} ] Cleanup callback failed: {t}", .{
                    @typeName(Ctx),
                    err,
                }),
            };
        }
    }.proxy);
}

fn cleanupAsyncProxy(
    comptime Ctx: type,
    comptime cb: CleanupAsync.Handler(Ctx),
) n.cleanup.CbAsync {
    const _Ctx = if (Ctx == void) AnyPtr else Ctx;

    return @ptrCast(&struct {
        pub fn proxy(hook: n.cleanup.AsyncHook, ctx: _Ctx) callconv(.c) void {
            const args = switch (Ctx) {
                void => .{CleanupAsync{ .hook = hook }},
                else => .{ ctx, CleanupAsync{ .hook = hook } },
            };

            @call(.always_inline, cb, args) catch |err| switch (Ctx) {
                void => log.err("Async cleanup callback failed - {t}", .{err}),
                else => log.err("[ {s} ] Async cleanup callback failed: {t}", .{
                    @typeName(Ctx),
                    err,
                }),
            };
        }
    }.proxy);
}
