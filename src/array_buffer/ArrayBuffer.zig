//! Represents a JS [ArrayBuffer](https://mdn.io/ArrayBuffer), contiguous block
//! of heap-allocated memory.
//!
//! Can be:
//! - Newly allocated via Node-API - `Env.arrayBuffer()`
//! - Extracted from an existing JS `Val` - `Val.arrayBuffer()`
//! - Copied from a native array/slice - `Env.arrayBufferFrom()`
//! - Created as a reference to addon-owned data - `Env.arrayBufferOwned()`
//! - Received as an argument in a native callback.

const std = @import("std");

const ArrayType = @import("typed_array.zig").ArrayType;
const Buffer = @import("Buffer.zig");
const DataView = @import("DataView.zig");
const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const Ref = @import("../root.zig").Ref;
const requireExternalBuffers = @import("../features.zig").requireExternalBuffers;
const requireNapiVersion = @import("../features.zig").requireNapiVersion;
const TypedArray = @import("typed_array.zig").TypedArray;
const Val = @import("../root.zig").Val;

const ArrayBuffer = @This();

/// The underlying, raw buffer data.
data: []u8,

/// The Node environment in which the Buffer was created.
env: Env,

/// The handle to the JS value for this Buffer.
ptr: Val,

/// Registers a native function to be called when the underlying JS value gets
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

/// Creates a NodeJS [Buffer](https://nodejs.org/api/buffer.html) as a view over
/// the given subset of the `ArrayBuffer`'s data.
///
/// Similar to the following in JS:
///
/// ```ts
/// import { Buffer } from "node:buffer";
///
/// function buffer(self: ArrayBuffer, offset: number, len: number) {
///   return Buffer.from(self, offset, len);
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#node_api_create_buffer_from_arraybuffer
pub fn buffer(self: ArrayBuffer, offset: usize, len: usize) !Buffer {
    requireNapiVersion(.v10);

    var ptr: ?Val = null;
    try n.node_api_create_buffer_from_arraybuffer(
        self.env,
        self.ptr,
        offset,
        len,
        &ptr,
    ).check();

    return .{
        .data = self.data[offset..][0..len],
        .env = self.env,
        .ptr = ptr.?,
    };
}

/// Creates a JS [DataView](https://mdn.io/DataView) as a view over the given
/// subset of the `ArrayBuffer`'s data.
///
/// Similar to the following in JS:
///
/// ```ts
/// function dataView(self: ArrayBuffer, offset: number, len: number) {
///   return new DataView(self, offset, len);
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_dataview
pub fn dataView(self: ArrayBuffer, offset: usize, len: usize) !DataView {
    var ptr: ?Val = null;
    try n.napi_create_dataview(self.env, len, self.ptr, offset, &ptr).check();

    return .{
        .buffer = self.ptr,
        .buffer_offset = offset,
        .data = self.data[offset..][0..len],
        .env = self.env,
        .ptr = ptr.?,
    };
}

/// Similar to the [ArrayBuffer.transfer](https://mdn.io/ArrayBuffer/transfer)
/// operation, removes the association between this ArrayBuffer and its
/// underlying byte buffer (e.g. detaching a JS `ArrayBuffer` created with
/// `Env.arrayBufferOwned()` from the native-owned memory).
///
/// Returns `Err.DetachableArrayBufferExpected` if called on a non-detachable
/// `ArrayBuffer`.
///
/// This feature requires the [`allow_external_buffers`](#tokota.Options) option
/// to be enabled.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_detach_arraybuffer
pub fn detach(self: ArrayBuffer) !void {
    requireExternalBuffers();

    try n.napi_detach_arraybuffer(self.env, self.ptr).check();
}

/// Equivalent to the [ArrayBuffer.detached](https://mdn.io/ArrayBuffer/detached)
/// JS property.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_detached_arraybuffer
pub fn isDetached(self: ArrayBuffer) !bool {
    var res: bool = undefined;
    try n.napi_is_detached_arraybuffer(self.env, self.ptr, &res).check();

    return res;
}

/// Creates a `Ref` from which the `ArrayBuffer` can later be extracted, outside
/// of the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: ArrayBuffer, initial_ref_count: u32) !Ref(ArrayBuffer) {
    var ptr: ?Ref(ArrayBuffer) = null;
    try n.napi_create_reference(self.env, self.ptr, initial_ref_count, &ptr)
        .check();

    return ptr.?;
}

/// Creates a JS [TypedArray](https://mdn.io/TypedArray)  as a view over the
/// given subset of the `ArrayBuffer`'s data.
///
/// > #### ⚠ NOTE
/// > `byte_offset` must be a multiple of the array data type's byte
/// > size. If not:
/// > - With runtime safety - a runtime panic will be triggered by a pointer
/// >   alignment safety check.
/// > - Without runtime safety - a JS `RangeError` exception will be thrown.
///
/// Similar to the following in JS (using a `Uint16Array` as an example):
///
/// ```ts
/// function typedArray(
///   self: ArrayBuffer,
///   byte_offset: number,
///   elem_count: number
/// ) {
///   return new Uint16Array(self, byte_offset, elem_count);
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_typedarray
pub fn typedArray(
    self: ArrayBuffer,
    comptime data_type: ArrayType,
    byte_offset: usize,
    elem_count: usize,
) !TypedArray(data_type) {
    const typed_data_ptr: []data_type.Zig() = @alignCast(
        @ptrCast(self.data[byte_offset..]),
    );

    var ptr: ?Val = null;
    try n.napi_create_typedarray(
        self.env,
        data_type,
        elem_count,
        self.ptr,
        byte_offset,
        &ptr,
    ).check();

    return .{
        .buffer = self.ptr,
        .buffer_offset = byte_offset,
        .data = typed_data_ptr[0..elem_count],
        .env = self.env,
        .ptr = ptr.?,
    };
}
