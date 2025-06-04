//! ArrayBuffer-specific methods of the `Val` API.

const std = @import("std");

const ArrayBuffer = @import("ArrayBuffer.zig");
const ArrayType = @import("typed_array.zig").ArrayType;
const Buffer = @import("Buffer.zig");
const DataView = @import("DataView.zig");
const Env = @import("../root.zig").Env;
const Err = @import("../root.zig").Err;
const n = @import("../napi.zig");
const TypedArray = @import("typed_array.zig").TypedArray;
const Val = @import("../root.zig").Val;

/// Returns information about the backing data of a JS `ArrayBuffer` value.
///
/// An error is returned if the JS value is not a `ArrayBuffer`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_arraybuffer_info
pub fn arrayBuffer(self: Val, env: Env) !ArrayBuffer {
    var buf_ptr: ?[*]u8 = null;
    var len: usize = undefined;
    try n.napi_get_arraybuffer_info(env, self, &buf_ptr, &len).check();

    const data: []u8 = if (buf_ptr) |p| p[0..len] else blk: {
        // NodeJS and Deno return null pointers for empty `ArrayBuffer`s.
        // Assert that's true if we receive a null.
        std.debug.assert(len == 0);
        break :blk &.{};
    };

    return .{
        .data = data,
        .env = env,
        .ptr = self,
    };
}

/// Returns information about the backing data of a JS `Buffer` value.
///
/// An error is returned if the JS value is not a `Buffer`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_buffer_info
pub fn buffer(self: Val, env: Env) !Buffer {
    var data: ?[*]u8 = null;
    var len: usize = undefined;
    try n.napi_get_buffer_info(env, self, &data, &len).check();

    return .{
        .data = data.?[0..len],
        .env = env,
        .ptr = self,
    };
}

/// Returns information about the backing data of a JS `DataView` value.
///
/// An error is returned if the JS value is not a `DataView`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_dataview_info
pub fn dataView(self: Val, env: Env) !DataView {
    var len: usize = undefined;
    var data_ptr: ?[*]u8 = undefined;
    var buf: ?Val = undefined;
    var buf_offset: usize = undefined;

    try n.napi_get_dataview_info(
        env,
        self,
        &len,
        @ptrCast(&data_ptr),
        &buf,
        &buf_offset,
    ).check();

    const data: []u8 = if (data_ptr) |p| p[0..len] else blk: {
        // NodeJS and Deno return null pointers for empty `DataView`s.
        // Assert that we only receive a null when that's the case.
        std.debug.assert(len == 0);
        break :blk &.{};
    };

    return .{
        .env = env,
        .data = data,
        .ptr = self,
        .buffer = buf.?,
        .buffer_offset = buf_offset,
    };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_arraybuffer
pub fn isArrayBuffer(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_arraybuffer(env, self, &res).check();

    return res;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_buffer
pub fn isBuffer(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_buffer(env, self, &res).check();

    return res;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_dataview
pub fn isDataView(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_dataview(env, self, &res).check();

    return res;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_typedarray
pub fn isTypedArray(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_typedarray(env, self, &res).check();

    return res;
}

/// Returns information about the backing data of a JS `TypedArray` value of the
/// given type.
///
/// An error is returned if the JS value is not a `TypedArray`, or has of a
/// different array data type.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_typedarray_info
pub fn typedArray(
    self: Val,
    env: Env,
    comptime arr_type: ArrayType,
) !TypedArray(arr_type) {
    const T = arr_type.Zig();

    var arr_type_actual: ArrayType = undefined;
    var len: usize = undefined;
    var data_ptr: ?[*]T = undefined;
    var buf: ?Val = undefined;
    var buf_offset: usize = undefined;

    n.napi_get_typedarray_info(
        env,
        self,
        &arr_type_actual,
        &len,
        @ptrCast(&data_ptr),
        &buf,
        &buf_offset,
    ).check() catch |err| return switch (err) {
        Err.InvalidArg, // node, deno
        Err.ObjectExpected, // bun
        => typeError(arr_type),
        else => |e| e,
    };

    if (arr_type_actual != arr_type) return typeError(arr_type);

    const data: []T = if (data_ptr) |p| p[0..len] else blk: {
        // NodeJS and Deno return null pointers for empty `TypedArray`s.
        // Assert that we only receive a null when that's the case.
        std.debug.assert(len == 0);
        break :blk &.{};
    };

    return .{
        .env = env,
        .data = data,
        .ptr = self,
        .buffer = buf.?,
        .buffer_offset = buf_offset,
    };
}

pub const TypedArrayExtractError = error{
    BigIntI64ArrayExpected,
    BigIntU64ArrayExpected,
    Float32ArrayExpected,
    Float64ArrayExpected,
    Int8ArrayExpected,
    Int16ArrayExpected,
    Int32ArrayExpected,
    Uint8ArrayExpected,
    Uint16ArrayExpected,
    Uint32ArrayExpected,
    Uint8ClampedArrayExpected,
};

fn typeError(comptime arr_type: ArrayType) TypedArrayExtractError {
    return comptime switch (arr_type) {
        .f32 => TypedArrayExtractError.Float32ArrayExpected,
        .f64 => TypedArrayExtractError.Float64ArrayExpected,
        .i16 => TypedArrayExtractError.Int16ArrayExpected,
        .i32 => TypedArrayExtractError.Int32ArrayExpected,
        .i64 => TypedArrayExtractError.BigIntI64ArrayExpected,
        .i8 => TypedArrayExtractError.Int8ArrayExpected,
        .u16 => TypedArrayExtractError.Uint16ArrayExpected,
        .u32 => TypedArrayExtractError.Uint32ArrayExpected,
        .u64 => TypedArrayExtractError.BigIntU64ArrayExpected,
        .u8 => TypedArrayExtractError.Uint8ArrayExpected,
        .u8c => TypedArrayExtractError.Uint8ClampedArrayExpected,
    };
}
