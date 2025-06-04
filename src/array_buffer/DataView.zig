//! Represents a JS [DataView](https://mdn.io/DataView).
//!
//! Can be:
//! - Created from an existing `ArrayBuffer` - `ArrayBuffer.dataView()`
//! - Extracted from an existing JS `Val` - `Val.dataView()`
//! - Copied from a native array/slice - `Env.dataViewFrom()`
//! - Received as an argument in a native callback.

const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

const DataView = @This();

/// Handle to the backing JS `ArrayBuffer` for this `DataView`.
///
/// More info can be retrieved via `DataView.buffer.arrayBuffer()`.
buffer: Val,

/// The offset from the start of `buffer` from which this `DataView` begins.
///
/// i.e. `data[0..]` is equivalent to `buffer[buffer_offset..][0..data.len]`.
buffer_offset: usize,

/// The underlying, raw buffer data.
data: []u8,

/// The Node environment in which the DataView was created.
env: Env,

/// The handle to the JS value for this `DataView`.
ptr: Val,

/// Registers a function to be called when the underlying JS value gets
/// garbage-collected. Enables cleanup of native values whose lifetime
/// should be tied to this JS value.
///
/// This API can be called multiple times on a single JS value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_add_finalizer
pub fn addFinalizer(self: DataView, finalizer: Finalizer) !Ref(DataView) {
    var ref_ptr: ?Ref(DataView) = null;
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

/// Creates a `Ref` from which the `DataView` can later be extracted, outside
/// of the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: DataView, initial_ref_count: u32) !Ref(DataView) {
    var ptr: ?Ref(DataView) = null;
    try n.napi_create_reference(self.env, self.ptr, initial_ref_count, &ptr)
        .check();

    return ptr.?;
}
