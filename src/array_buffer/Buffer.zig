//! Represents a NodeJS [Buffer](https://nodejs.org/api/buffer.html).
//!
//! While this is still a fully-supported data structure, in most cases using a
//! TypedArray will suffice.
//!
//! Can be:
//! - Newly allocated via Node-API - `Env.buffer()`
//! - Extracted from an existing JS `Val` - `Val.buffer()`
//! - Copied from a native array/slice - `Env.bufferFrom()`
//! - Created from an existing `ArrayBuffer` - `ArrayBuffer.buffer()`
//! - Received as an argument in a native callback.

const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

const Buffer = @This();

/// The backing memory for `Buffer`.
///
/// > #### ⚠ NOTE
/// > This memory is JS-owned and only valid until the JS object is GC'd. It's
/// not recommended to rely on the backing memory being available beyond the
/// scope within which it was created or received without first creating a
/// reference with `ref()`.
data: []u8,

/// The Node environment in which the Buffer was created.
env: Env,

/// The handle to the JS value for this Buffer.
ptr: Val,

/// Registers a native function to be called when the underlying JS value gets
/// garbage-collected. Enables cleanup of native values whose lifetime should be
/// tied to this JS value.
///
/// This API can be called multiple times on a single JS value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_add_finalizer
pub fn addFinalizer(self: Buffer, finalizer: Finalizer) !Ref(Buffer) {
    var ref_ptr: ?Ref(Buffer) = null;
    try n.napi_add_finalizer(
        self.env,
        self.ptr,
        finalizer.data,
        finalizer.cb.?,
        finalizer.hint,
        &ref_ptr,
    ).check();

    return ref_ptr.?;
}

/// Creates a `Ref` from which the `Buffer` can later be extracted, outside
/// of the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: Buffer, initial_ref_count: u32) !Ref(Buffer) {
    var ptr: ?Ref(Buffer) = null;
    try n.napi_create_reference(self.env, self.ptr, initial_ref_count, &ptr)
        .check();

    return ptr.?;
}
