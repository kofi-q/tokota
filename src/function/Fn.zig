//! Represents a callable JS [`Function`](https://mdn.io/Reference/Global_Objects/Function)
//! object.
//!
//! Can be:
//! - Created from a Zig function - `Env.function()`.
//! - Extracted from an existing `Val` - `Val.function()`.
//!
//! ## Example:
//! ```zig
//! //! addon.zig
//!
//! const std = @import("std");
//! const t = @import("tokota");
//!
//! comptime {
//!     t.exportModule(@This());
//! }
//!
//! /// Receiving a `Fn` in a native callback will extract the function from
//! /// the corresponding JS `Val` arg via `Val.function()`.
//! pub fn callSingleArgFn(arg: t.Val, cb: t.Fn) @TypeOf(callMultiArgFn) {
//!     _ = cb.call(arg) catch unreachable;
//!
//!     // Returned Zig `fn`s will get converted to JS functions via
//!     // `Env.function()`
//!     return callMultiArgFn;
//! }
//!
//! fn callMultiArgFn(path: t.TinyStr(255), cb: t.Fn) !void {
//!     // JS `Fn`s can be called with multiple args in a tuple, each of which
//!     // get converted to `Val` (if non-`Val`) via `Env.infer()`.
//!     _ = try cb.call(.{
//!         std.fs.path.dirname(path.slice()) orelse "",
//!         std.fs.path.basename(path.slice()),
//!     });
//! }
//! ```
//!
//! ```js
//! // main.js
//!
//! const assert = require("node:assert");
//! const addon = require("./addon.node");
//!
//! let receivedArgSingle;
//! const callMultiArgFn = addon.callSingleArgFn("foo", arg => {
//!   receivedArgSingle = arg;
//! });
//!
//! assert.equal(receivedArgSingle, "foo");
//! assert.equal(typeof callMultiArgFn, "function");
//!
//! let receivedArgsMulti;
//! callMultiArgFn("/path/to/foo", (...args) => {
//!   receivedArgsMulti = args;
//! });
//!
//! assert.deepEqual(receivedArgsMulti, ["/path/to", "foo"]);
//! ```

const std = @import("std");

const ArgOrArgsTuple = @import("./args.zig").ArgOrArgsTuple;
const argValues = @import("./args.zig").argValues;
const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const Ref = @import("../root.zig").Ref;
const tsfn = @import("../async/threadsafe_fn.zig");
const Val = @import("../root.zig").Val;

const Fn = @This();

/// The pointer to the JS function object. Can be returned to JS callers from
/// Node-API callbacks.
ptr: Val,

/// Pointer to the Node environment within which `ptr` was created.
env: Env,

/// Registers a function to be called when the underlying JS value gets
/// garbage-collected. Enables cleanup of native values whose lifetime should be
/// tied to the JS function.
///
/// This API can be called multiple times on a single JS value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_add_finalizer
pub fn addFinalizer(self: Fn, finalizer: Finalizer) !Ref(Fn) {
    var ref_ptr: ?Ref(Fn) = null;
    try n.napi_add_finalizer(
        self.env,
        self.ptr,
        finalizer.data,
        finalizer.cb.?,
        finalizer.hint,
        @ptrCast(&ref_ptr),
    ).check();

    return ref_ptr.?;
}

/// Makes a call to the JS function with the given args and returns the result
/// of the call.
///
/// `arg_or_args` can be a single value of a tuple of values, each of which can
/// be a `Val`, or a type for which inferred conversion is supported, via
/// `Env.infer()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_call_function
pub fn call(self: Fn, arg_or_args: anytype) !Val {
    const args = try argValues(self.env, arg_or_args);

    var result: ?Val = null;
    try n.napi_call_function(
        self.env,
        (try self.env.global()).ptr,
        self.ptr,
        args.len,
        args.ptr,
        &result,
    ).check();

    return result.?;
}

/// Makes a call to the JS function with the given `this` object and function
/// args. Returns the result of the call.
///
/// `arg_or_args` can be a single value of a tuple of values, each of which can
/// be a `Val`, or a type for which inferred conversion is supported, via
/// `Env.infer()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_call_function
pub fn callThis(self: Fn, this: Val, arg_or_args: anytype) !Val {
    const args = try argValues(self.env, arg_or_args);

    var result: ?Val = null;
    try n.napi_call_function(
        self.env,
        this,
        self.ptr,
        args.len,
        args.ptr,
        &result,
    ).check();

    return result.?;
}

/// Creates a `Ref` from which the `Fn` can later be extracted, outside
/// of the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: Fn, initial_ref_count: u32) !Ref(Fn) {
    var ptr: ?Ref(Fn) = null;
    try n.napi_create_reference(
        self.env,
        self.ptr,
        initial_ref_count,
        @ptrCast(&ptr),
    ).check();

    return ptr.?;
}

const async_ext = @import("../async/Fn.zig");
pub const threadsafeFn = async_ext.threadsafeFn;

/// [Unstable] This is experimental. May be removed soon.
///
/// `arg_types` can be a single type of a tuple of type, each of which can
/// be a `Val`, or a type for which inferred conversion is supported,
/// via `Env.infer()`.
pub fn Typed(comptime arg_types: anytype, comptime ReturnType: type) type {
    const Args = ArgOrArgsTuple(arg_types);

    return struct {
        const Self = @This();

        inner: Fn,

        /// Registers a native function to be called when the underlying JS
        /// value gets garbage-collected. Enables cleanup of native values whose
        /// lifetime should be tied to this JS value.
        ///
        /// This API can be called multiple times on a single JS value.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_add_finalizer
        pub fn addFinalizer(self: Self, finalizer: Finalizer) !Ref(Self) {
            var ref_ptr: ?Ref(Self) = null;
            try n.napi_add_finalizer(
                self.env,
                self.ptr,
                finalizer.data,
                finalizer.cb.?,
                finalizer.hint,
                @ptrCast(&ref_ptr),
            ).check();

            return ref_ptr.?;
        }

        /// Makes a call to the JS function with the given args and returns the
        /// result of the call.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_call_function
        pub inline fn call(self: Self, args: Args) !ReturnType {
            const res = try self.inner.call(args);
            return res.to(self.inner.env, ReturnType);
        }

        /// Makes a call to the JS function with the given `this` object and
        /// function args. Returns the result of the call.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_call_function
        pub inline fn callThis(self: Self, this: Val, args: Args) !ReturnType {
            const res = try self.inner.callThis(this, args);
            return res.to(self.inner.env, ReturnType);
        }

        /// Creates a `Ref` from which the `Fn` can later be extracted, outside
        /// of the function scope within which it was initially created or
        /// received.
        ///
        /// > #### ⚠ NOTE
        /// > References prevent a JS value from being garbage collected. A
        /// corresponding call to `Ref.unref()` or `Ref.delete()` is required
        /// for proper disposal.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
        pub fn ref(self: Self, initial_ref_count: u32) !Ref(Self) {
            var ptr: ?Ref(Self) = null;
            try n.napi_create_reference(
                self.env,
                self.ptr,
                initial_ref_count,
                @ptrCast(&ptr),
            ).check();

            return ptr.?;
        }

        pub fn fromJs(env: Env, val: Val) !Self {
            return val.functionTyped(env, Args, ReturnType);
        }
    };
}
