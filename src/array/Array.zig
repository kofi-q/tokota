//! Represents a JS [Array](https://mdn.io/Array) or array-like object.
//! Provides methods for array element inspection and manipulation.
//!
//! Can be:
//! - Newly allocation via `Env.array()` or `Env.arrayN()`.
//! - Derived from an existing JS value via `Val.array()`.
//! - Received as an argument in a Node-API callback.
//!
//! ## Example
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
//! pub fn create(call: t.Call) !t.Array {
//!     const array = try call.env.array();
//!     try array.set(0, "one");
//!     try array.set(1, true);
//!     try array.set(2, 3.142);
//!
//!     return array;
//! }
//!
//! const MixedBag = struct { []const u8, bool, f64 };
//!
//! pub fn convert() MixedBag {
//!     return .{ "one", true, 3.142 };
//! }
//!
//! pub fn modify(array: t.Array) !t.Array {
//!     const item_0 = try array.getT(0, t.TinyStr(16));
//!     const item_1 = try array.getT(1, bool);
//!
//!     std.mem.reverse(u8, item_0.buf[0..item_0.len]);
//!
//!     try array.set(0, item_0);
//!     try array.set(1, !item_1);
//!     std.debug.assert(try array.delete(2));
//!
//!     return array;
//! }
//! ```
//!
//! ```js
//! // main.js
//!
//! const assert = require("node:assert");
//! const addon = require("./addon.node");
//!
//! assert.deepEqual(addon.create(), ["one", true, 3.142]);
//! assert.deepEqual(addon.convert(), ["one", true, 3.142]);
//!
//! const expected = ["eno", false, "delete me"];
//! delete expected[2];
//! assert.deepEqual(addon.modify(["one", true, 3.142]), expected);
//! ```

const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

const Array = @This();

/// Environment within which this JS array created.
env: Env,

/// Pointer to the underlying JS array.
ptr: Val,

/// Registers a native function to be called when the underlying JS value gets
/// garbage-collected. Enables cleanup of native values whose lifetime should be
/// tied to this JS value.
///
/// This API can be called multiple times on a single JS value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_add_finalizer
pub fn addFinalizer(self: Array, finalizer: Finalizer) !Ref(Array) {
    var ref_ptr: ?Ref(Array) = null;
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

/// Attempts to delete the element at `idx` on the array/array-like object.
/// Returns `true` if an element was deleted.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_delete_element
pub fn delete(self: Array, idx: usize) !bool {
    var res: bool = false;
    try n.napi_delete_element(self.env, self.ptr, @intCast(idx), &res).check();

    return res;
}

/// Returns the element at `idx`, or a JS `undefined` value if the `idx` is not
/// set on the array/array-like object.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_element
pub fn get(self: Array, idx: usize) !Val {
    var elem: ?Val = null;
    try n.napi_get_element(self.env, self.ptr, @intCast(idx), &elem).check();

    return elem.?;
}

/// Returns the element at `idx` as the given Zig type, `T`.
///
/// If `idx` is unset on the array/object a `null` is returned if `T` is an
/// optional type - otherwise, an error is returned.
///
/// Performs runtime validation on the JS value based on `T` and returns errors
/// for incompatible types.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_element
pub inline fn getT(self: Array, idx: usize, comptime T: type) !T {
    var elem: ?Val = null;
    try n.napi_get_element(self.env, self.ptr, @intCast(idx), &elem).check();

    return elem.?.to(self.env, T);
}

/// Returns `true` iff an element is set at `idx` in the array.
///
///  https://nodejs.org/docs/latest/api/n-api.html#napi_has_element
pub fn isSet(self: Array, idx: usize) !bool {
    var result: bool = undefined;
    try n.napi_has_element(self.env, self.ptr, @intCast(idx), &result).check();

    return result;
}

/// Returns the length (capacity, not element count) of the array/array-like
/// object.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_array_length
pub fn len(self: Array) !usize {
    var result: u32 = undefined;
    try n.napi_get_array_length(self.env, self.ptr, &result).check();

    return result;
}

/// Creates a `Ref` from which the `Array` can later be extracted, outside of
/// the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: Array, initial_ref_count: u32) !Ref(Array) {
    var ptr: ?Ref(Array) = null;
    try n.napi_create_reference(
        self.env,
        self.ptr,
        initial_ref_count,
        @ptrCast(&ptr),
    ).check();

    return ptr.?;
}

/// Sets `idx` in the array to the given element. Non-`Val` types are converted
/// to `Val` first, if supported (see `Env.infer()`).
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_set_element
pub fn set(self: Array, idx: usize, elem: anytype) !void {
    const val = try self.env.infer(elem);
    try n.napi_set_element(self.env, self.ptr, @intCast(idx), val).check();
}
