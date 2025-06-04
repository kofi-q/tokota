//! String-specific methods of the `Val` API.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// The UTF8-encoded string representation of the value, if it is a
/// string type.
///
/// > #### ⚠ NOTE
/// > If the string is longer than `buf_len`, it string will be
/// truncated. If unsure, use `stringLen()` in conjunction with `stringBuf()`
/// instead, or use `stringAlloc()` with an allocator.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf8
pub inline fn string(self: Val, env: Env, buf_len: comptime_int) ![:0]u8 {
    var buf: [buf_len + 1]u8 = undefined;
    var len: usize = undefined;

    try n.napi_get_value_string_utf8(env, self, buf[0..].ptr, buf.len, &len)
        .check();

    return buf[0..len :0];
}

/// The UTF8-encoded, heap-allocated string representation of the value, if
/// it is a string type.
///
/// Caller owns the memory.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf8
pub fn stringAlloc(self: Val, env: Env, allo: Allocator) ![:0]u8 {
    const len = try self.stringLen(env) + 1;
    return self.stringBuf(env, try allo.alloc(u8, len));
}

/// The UTF8-encoded string representation of the value, if it is a
/// string type.
///
/// > #### ⚠ NOTE
/// > If `buf` is not large enough to fit the full length of the
/// string plus a null terminator byte, the string will be truncated. If
/// unsure, use `stringLen()` first to determine how much space should be
/// allocated, or use `stringAlloc()` with an allocator.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf8
pub fn stringBuf(self: Val, env: Env, buf: []u8) ![:0]u8 {
    var len: usize = undefined;
    try n.napi_get_value_string_utf8(env, self, buf.ptr, buf.len, &len).check();

    return buf[0..len :0];
}

/// The equivalent of a `toString()` operation on a JS value. If successful, the
/// resulting string may be extracted from the returned `Val` with any of the
/// available `Val` string methods, as needed.
///
/// Returns a newly allocated `Val`. The original `Val` remains unchanged.
///
/// https://nodejs.org/api/n-api.html#napi_coerce_to_string
pub fn stringCoerce(self: Val, env: Env) !Val {
    var val: ?Val = null;
    try n.napi_coerce_to_string(env, self, &val).check();

    return val.?;
}

/// The byte length of the UTF8-encoded string representation of the value
/// (excluding the null terminator), if it is a string type.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf8
pub fn stringLen(self: Val, env: Env) !usize {
    var len: usize = 0;
    try n.napi_get_value_string_utf8(env, self, null, 0, &len).check();

    return len;
}

/// The ISO-8859-1-encoded string representation of the value, if it is a
/// string type.
///
/// > #### ⚠ NOTE
/// > If the string is longer than `buf_len`, it string will be
/// truncated. If unsure, use `strLatin1Len()` in conjunction with `strLatin1`
/// instead, or use `strLatin1Alloc()` with an allocator.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_latin1
pub inline fn strLatin1(self: Val, env: Env, buf_len: comptime_int) ![:0]u8 {
    var buf: [buf_len + 1]u8 = undefined;
    var len: usize = undefined;

    try n.napi_get_value_string_latin1(env, self, buf[0..].ptr, buf.len, &len)
        .check();

    return buf[0..len :0];
}

/// The ISO-8859-1-encoded, heap-allocated string representation of the value,
/// if it is a string type.
///
/// Caller owns the memory.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_latin1
pub fn strLatin1Alloc(self: Val, env: Env, allo: Allocator) ![:0]u8 {
    const len = try self.strLatin1Len(env) + 1;

    return self.strLatin1Buf(env, try allo.alloc(u8, len));
}

/// The ISO-8859-1-encoded string representation of the value, if it is a
/// string type.
///
/// > #### ⚠ NOTE
/// If `buf` is not large enough to fit the full length of the
/// string plus a null terminator byte, the string will be truncated. If
/// unsure, use `strLatin1Len()` first to determine how much space should be
/// allocated, or use `strLatin1Alloc()` with an allocator.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_latin1
pub fn strLatin1Buf(self: Val, env: Env, buf: []u8) ![:0]u8 {
    var len: usize = undefined;
    try n.napi_get_value_string_latin1(env, self, buf.ptr, buf.len, &len)
        .check();

    return buf[0..len :0];
}

/// The byte length of the ISO-8859-1-encoded string representation of the value
/// (excluding the null terminator), if it is a string type.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_latin1
pub fn strLatin1Len(self: Val, env: Env) !usize {
    var len: usize = 0;
    try n.napi_get_value_string_latin1(env, self, null, 0, &len).check();

    return len;
}

/// The UTF16-LE-encoded string representation of the value, if it is a
/// string type.
///
/// > #### ⚠ NOTE
/// > If the string is longer than `buf_len`, it string will be
/// truncated. If unsure, use `strUtf16Len` in conjunction with `strUtf16`
/// instead, or use `strUtf16Alloc` with an allocator.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf8
pub inline fn strUtf16(self: Val, env: Env, buf_len: comptime_int) ![:0]u16 {
    var buf: [buf_len + 1]u16 = undefined;
    var len: usize = undefined;

    try n.napi_get_value_string_utf16(env, self, buf[0..].ptr, buf.len, &len)
        .check();

    return buf[0..len :0];
}

/// The UTF16-encoded, heap-allocated string representation of the value, if
/// it is a string type.
///
/// Caller owns the memory.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf16
pub fn strUtf16Alloc(self: Val, env: Env, allo: Allocator) ![:0]u16 {
    const len = try self.strUtf16Len(env) + 1;

    return self.strUtf16Buf(env, try allo.alloc(u16, len));
}

/// The UTF16-LE-encoded string representation of the value, if it is a
/// string type.
///
/// Caller is responsible for converting to native endianness, if necessary.
///
/// > #### ⚠ NOTE
/// > If `buf` is not large enough to fit the full length of the
/// string plus a null terminator, the string will be truncated. If unsure
/// use `strUtf16Len()` first to determine how much space should be allocated,
/// or use `strUtf16Alloc()` with an allocator.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf16
pub fn strUtf16Buf(self: Val, env: Env, buf: []u16) ![:0]u16 {
    var len: usize = buf.len;
    try n.napi_get_value_string_utf16(env, self, buf.ptr, buf.len, &len)
        .check();

    return buf[0..len :0];
}

/// The number of 2-byte codepoints in the UTF16-encoded string representation
/// of the value (excluding the null terminator), if it is a string type.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_string_utf16
pub fn strUtf16Len(self: Val, env: Env) !usize {
    var len: usize = 0;
    try n.napi_get_value_string_utf16(env, self, null, 0, &len).check();

    return len;
}
