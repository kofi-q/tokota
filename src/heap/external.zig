const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const Err = @import("../root.zig").Err;
const Finalizer = @import("../root.zig").Finalizer;
const Val = @import("../root.zig").Val;

/// Argument receiver for extracting external (native) data attached to a JS
/// value. External objects are created via `Env.external()`.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// const Client = struct {
///     comptime js_tag: t.Object.Tag = .{ .lower = 0xcafe, .upper = 0xf00d },
///     foo: u32,
/// };
///
/// var client: Client = undefined;
///
/// pub fn newClient(call: t.Call, foo: u32) !t.Val {
///     client = .{ .foo = foo };
///     return call.env.external(&client, .none);
/// }
///
/// pub fn clientFoo(client: t.External(*Client)) !u32 {
///     return client.ptr.foo;
/// }
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const addon = require("./addon.node");
///
/// const client = addon.newClient(42);
/// assert.equal(addon.clientFoo(client), 42);
///
/// const notClient = { foo: 42 };
/// assert.throws(() => addon.clientFoo(notClient), /NativeObjectExpected/);
/// ```
pub fn External(comptime PtrType: type) type {
    return struct {
        ptr: PtrType,

        pub fn fromJs(env: Env, arg: Val) !@This() {
            const ptr = arg.external(PtrType, env) catch |err| {
                return switch (err) {
                    // [TODO] Should this disambiguate between non-native
                    // objects and native objects with mismatched tags?
                    Err.InvalidArg => error.NativeObjectExpected,
                    else => err,
                };
            };

            return .{ .ptr = ptr };
        }
    };
}
