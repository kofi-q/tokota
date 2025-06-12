const std = @import("std");
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const t = @import("../root.zig");
const Val = @import("../root.zig").Val;

/// A reference to a JS value, providing a means for explicitly managing a
/// value's lifetime. `Ref.ref()` and `Ref.unref()` will increment and decrement
/// the count of references to the value, preventing garbage collection until
/// the reference count reaches 0.
///
/// JS types that support references have a ref method available, e.g.
/// `Object.ref()`, `ArrayBuffer.ref()`, etc. Starting in `NapiVersion`.`v10`,
/// references can be created for any JS value via, `Val.ref()`.
///
/// > #### ⚠ NOTE
/// > Attempting to use a `Ref` after a call to `Ref.delete()` is unchecked
/// illegal behaviour and may result in the process being aborted.
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
/// var object_ref: t.Ref(t.Object) = undefined;
///
/// pub fn stash(object: t.Object) !void {
///     object_ref = try object.ref(1);
/// }
///
/// pub fn stashGet(call: t.Call) !t.Object {
///     defer object_ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
///         .code = @errorName(err),
///         .msg = "Unable to delete ref",
///     });
///
///     return try object_ref.val(call.env) orelse error.BrokenRef;
/// }
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const addon = require("./addon.node");
///
/// const object = { foo: true };
/// addon.stash(object);
/// assert.strictEqual(addon.stashGet(), object);
/// ```
/// https://nodejs.org/docs/latest/api/n-api.html#napi_ref
pub fn Ref(comptime T: type) type {
    const NapiRef = opaque {
        const Self = *const @This();

        /// Deletes this reference, allowing the referenced value to be garbage
        /// collected if/when there are no other remaining references to it.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_delete_reference
        pub fn delete(self: Self, env: Env) !void {
            try n.napi_delete_reference(env, @ptrCast(self)).check();
        }

        /// Increases the reference count for the corresponding JS value by `1` and
        /// returns the new reference count.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_reference_ref
        pub fn ref(self: Self, env: Env) !u32 {
            var ref_count: u32 = undefined;
            try n.napi_reference_ref(env, @ptrCast(self), &ref_count).check();

            return ref_count;
        }

        /// Reduces the reference count for the corresponding JS value by `1` and
        /// returns the new reference count.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_reference_unref
        pub fn unref(self: Self, env: Env) !u32 {
            var ref_count: u32 = undefined;
            try n.napi_reference_unref(env, @ptrCast(self), &ref_count).check();

            return ref_count;
        }

        /// Retrieves the previously referenced value.
        ///
        /// Returns `null` if the ref is no longer valid. However, this
        /// behaviour should not be relied on for determining ref validity, as
        /// it is inconsistent and attempts to extract values from
        /// invalid/deleted refs may result in panic.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_reference_value
        pub fn val(self: Self, env: Env) !?T {
            var ptr: ?Val = null;
            try n.napi_get_reference_value(env, @ptrCast(self), &ptr).check();

            return try (ptr orelse return null).to(env, T);
        }
    };

    return NapiRef.Self;
}
