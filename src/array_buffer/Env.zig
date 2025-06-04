//! `Env` API methods for creating JS `ArrayBuffer`s (and its derived types).

const ArrayBuffer = @import("ArrayBuffer.zig");
const ArrayType = @import("typed_array.zig").ArrayType;
const Buffer = @import("Buffer.zig");
const DataView = @import("DataView.zig");
const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const requireExternalBuffers = @import("../features.zig").requireExternalBuffers;
const TypedArray = @import("typed_array.zig").TypedArray;
const Val = @import("../root.zig").Val;

/// Returns a newly allocated JS `ArrayBuffer` of length `len`.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference with `ArrayBuffer.ref()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_arraybuffer
pub fn arrayBuffer(self: Env, len: usize) !ArrayBuffer {
    var data: [*]u8 = undefined;
    var ptr: ?Val = null;
    try n.napi_create_arraybuffer(self, len, &data, &ptr).check();

    return .{
        .data = data[0..len],
        .env = self,
        .ptr = ptr.?,
    };
}

/// Returns a newly allocated JS `ArrayBuffer` of length `data.len` with `data`
/// copied into its backing memory.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference with `ArrayBuffer.ref()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_arraybuffer
pub fn arrayBufferFrom(self: Env, data: []const u8) !ArrayBuffer {
    const buf = try self.arrayBuffer(data.len);
    @memcpy(buf.data, data);

    return buf;
}

/// Returns a JS `ArrayBuffer` backed by the provided pre-allocated buffer.
///
/// Caller retains ownership of ` buf`, which must remain valid at least until
/// the given finalizer callback, if any, is called.
///
/// > #### ⚠ NOTE
/// > This is not supported by all runtimes, for safety reasons, and is
/// recommended to be used only if absolutely necessary. Consider allocating an
/// `ArrayBuffer` with `arrayBuffer()`  and passing the underlying buffer
/// around instead, if feasible.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_external_arraybuffer
pub fn arrayBufferOwned(
    self: Env,
    buf: []u8,
    finalizer_partial: Finalizer.Partial([*]u8),
) !ArrayBuffer {
    requireExternalBuffers();

    var ptr: ?Val = null;
    try n.napi_create_external_arraybuffer(
        self,
        buf.ptr,
        buf.len,
        finalizer_partial.finalizer.cb,
        finalizer_partial.finalizer.hint,
        &ptr,
    ).check();

    return .{
        .data = buf,
        .env = self,
        .ptr = ptr.?,
    };
}

/// Allocates a NodeJS `Buffer` object of length `len`.
///
/// While this is still a fully-supported data structure, in most cases using a
/// `TypedArray` will suffice.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference with `Buffer.ref()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_buffer
pub fn buffer(self: Env, len: usize) !Buffer {
    var data: [*]u8 = undefined;
    var ptr: ?Val = null;
    try n.napi_create_buffer(self, len, &data, &ptr).check();

    return .{
        .data = data[0..len],
        .env = self,
        .ptr = ptr.?,
    };
}

/// Returns a NodeJS `Buffer` backed by a newly allocated `ArrayBuffer`
/// containing a copy of `data`.
///
/// While this is still a fully-supported data structure, in most cases using a
/// `TypedArray` will suffice.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference with `Buffer.ref()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_buffer_copy
pub fn bufferFrom(self: Env, data: []const u8) !Buffer {
    var buf: [*]u8 = undefined;
    var ptr: ?Val = null;
    try n.napi_create_buffer_copy(self, data.len, data.ptr, &buf, &ptr).check();

    return .{
        .data = buf[0..data.len],
        .env = self,
        .ptr = ptr.?,
    };
}

/// Returns a NodeJS `Buffer` backed by the provided Zig buffer.
///
/// Caller retains ownership of `buf`, which must remain valid at least until
/// the given finalizer callback, if any, is called.
///
/// > #### ⚠ NOTE
/// > This is not supported by all runtimes for safety reasons and is
/// recommended to be used only if absolutely necessary. Consider allocating an
/// `Buffer` with `Env.buffer()` and passing the underlying buffer around
/// instead, if feasible.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_external_buffer
pub fn bufferOwned(
    self: Env,
    buf: []u8,
    finalizer_partial: Finalizer.Partial([*]u8),
) !Buffer {
    requireExternalBuffers();

    var ptr: ?Val = null;
    try n.napi_create_external_buffer(
        self,
        buf.len,
        buf.ptr,
        finalizer_partial.finalizer.cb,
        finalizer_partial.finalizer.hint,
        &ptr,
    ).check();

    return .{
        .data = buf,
        .env = self,
        .ptr = ptr.?,
    };
}

/// Returns a newly allocated JS `DataView` of length `len`.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference with `DataView.ref()`.
///
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_arraybuffer
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_dataview
pub fn dataView(self: Env, len: usize) !DataView {
    const array_buffer = try self.arrayBuffer(len);
    return array_buffer.dataView(0, len);
}

/// Returns a JS `DataView` backed by a newly allocated `ArrayBuffer`
/// containing a copy of `data`.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference with `DataView.ref()`.
///
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_arraybuffer
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_dataview
pub fn dataViewFrom(self: Env, data: []const u8) !DataView {
    const array_buffer = try self.arrayBufferFrom(data);
    return array_buffer.dataView(0, data.len);
}

/// Returns a newly allocated JS `TypedArray` of the given type and length.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference
/// with `TypedArray.ref()`.
///
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_arraybuffer
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_typedarray
pub fn typedArray(
    self: Env,
    comptime data_type: ArrayType,
    len: usize,
) !TypedArray(data_type) {
    const byte_length = len * data_type.size();
    const array_buffer = try self.arrayBuffer(byte_length);

    return array_buffer.typedArray(data_type, 0, len);
}

/// Returns a newly allocated JS `TypedArray` with a data type matching the
/// element type of the given `data` slice or array. `data` is copied into the
/// backing memory for the `TypedArray` before returning.
///
/// > #### ⚠ NOTE
/// > The resulting memory is JS-owned and only valid until the JS
/// object is GC'd. It's not recommended to rely on the backing memory being
/// available beyond the scope within which it was created or received without
/// first creating a reference
/// with `TypedArray.ref()`.
///
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_arraybuffer
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_typedarray
pub fn typedArrayFrom(self: Env, data: anytype) !TypedArray(
    ArrayType.from(@TypeOf(data)),
) {
    const data_type = ArrayType.from(@TypeOf(data));
    const array = try self.typedArray(data_type, data.len);
    @memcpy(array.data, data[0..]);

    return array;
}
