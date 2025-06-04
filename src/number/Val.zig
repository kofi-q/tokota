const Allocator = std.mem.Allocator;
const std = @import("std");

const BigInt = @import("BigInt.zig");
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// Returns a `ZigInt` representation of the JS `BigInt` value.
///
/// Returns `error.InvalidArg` or `error.BigIntExpected` for `undefined` or
/// non-`BigInt` values.
///
/// Returns a `BigInt.Error` if the value cannot be represented by `ZigInt`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_bigint_words
pub fn bigInt(self: Val, env: Env, comptime ZigInt: type) !ZigInt {
    const word_count = BigInt.wordCount(ZigInt);
    var buf: [word_count]BigInt.Word = undefined;

    const big_int = try self.bigIntBuf(env, &buf);
    @memset(buf[big_int.words.len..], 0);

    return BigInt.castStatic(ZigInt, &buf, big_int.negative);
}

/// Returns a `BigInt` representation of the JS `BigInt` value, with the given
/// buffer as word storage.
///
/// The length of buffer required can be determined via `Val.bigIntWordCount()`.
///
/// Returns `error.InvalidArg` or `error.BigIntExpected` for `undefined` or
/// non-`BigInt` values.
///
/// Returns `error.BigIntOverflow` if the buffer is not large enough.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_bigint_words
pub inline fn bigIntBuf(self: Val, env: Env, buf: []BigInt.Word) !BigInt {
    var word_count = buf.len;
    var sign: c_uint = undefined;

    try n.napi_get_value_bigint_words(env, self, &sign, &word_count, buf.ptr)
        .check();

    if (word_count > buf.len) return BigInt.Error.BigIntOverflow;

    return .{
        .negative = @bitCast(@as(u1, @truncate(sign))),
        .words = buf[0..word_count],
    };
}

/// The `i64` representation of this JS `BigInt` value, along with a `lossless`
/// indicator flag, which should be checked before use.
///
/// Returns `error.InvalidArg` or `error.BigIntExpected` for `undefined` or
/// non-`BigInt` values.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_bigint_int64
pub fn bigIntI64(self: Val, env: Env) !BigInt.I64 {
    var bi: BigInt.I64 = undefined;
    try n.napi_get_value_bigint_int64(env, self, &bi.val, &bi.lossless).check();

    return bi;
}

/// The `u64` representation of this JS `BigInt` value, along with a `lossless`
/// indicator flag, which should be checked before use.
///
/// Returns `error.InvalidArg` or `error.BigIntExpected` for `undefined` or
/// non-`BigInt` values.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_bigint_uint64
pub fn bigIntU64(self: Val, env: Env) !BigInt.U64 {
    var bi: BigInt.U64 = undefined;
    try n.napi_get_value_bigint_uint64(env, self, &bi.val, &bi.lossless)
        .check();

    return bi;
}

/// The number of 64-bit words needed to represent this JS `BigInt` value.
///
/// Returns `error.InvalidArg` or `error.BigIntExpected` for `undefined` or
/// non-`BigInt` values.
///
/// https://nodejs.org/api/n-api.html#napi_get_value_bigint_words
pub fn bigIntWordCount(self: Val, env: Env) !usize {
    var word_count: usize = 0;
    try n.napi_get_value_bigint_words(env, self, null, &word_count, null)
        .check();

    return word_count;
}

/// An `f64` representation of this JS `Number` value. Returns
/// `error.InvalidArg` or `error.NumberExpected` for `undefined` or non-`Number`
/// values.
///
/// This is a bit-equivalent representation of JS `Number`. All other available
/// `Number`-related methods provide lossy derivations and are labelled as such.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_double
pub fn float64(self: Val, env: Env) !f64 {
    var val: f64 = undefined;
    try n.napi_get_value_double(env, self, &val).check();

    return val;
}

/// Returns a new JS `Number` value pointer, coerced from the original,
/// potentially non-`Number` value. If successful, the resulting number value
/// can then be safely extracted with the relevant float/integer `Val` methods.
///
/// Returns a newly allocated `Val`. The original `Val` remains unchanged.
///
/// https://nodejs.org/api/n-api.html#napi_coerce_to_number
pub fn numberCoerce(self: Val, env: Env) !Val {
    var res: ?Val = null;
    try n.napi_coerce_to_number(env, self, &res).check();

    return res.?;
}

/// An `i32` representation of this JS `Number` value. Returns
/// `error.InvalidArg` or `error.NumberExpected` for `undefined` or non-`Number`
/// values.
///
/// > #### ⚠ NOTE
/// > This is lossy if the JS `Number` is a non-integer, or cannot be
/// represented by an `i32`. Prefer using `Val.float64()`, or `Val.to()` -
/// the latter performs runtime checks to ensure lossless conversion.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_int32
pub fn unsafeI32(self: Val, env: Env) !i32 {
    var val: i32 = undefined;
    try n.napi_get_value_int32(env, self, &val).check();

    return val;
}

/// Returns an `u32` representation of this JS `Number` value. Returns
/// `error.InvalidArg` or `error.NumberExpected` for `undefined` or non-`Number`
/// values.
///
/// > #### ⚠ NOTE
/// > This is lossy if the JS `Number` is a non-integer, or cannot be
/// represented by an `u32`. Prefer using `Val.float64()`, or `Val.to()` -
/// the latter performs runtime checks to ensure lossless conversion.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_value_uint32
pub fn unsafeU32(self: Val, env: Env) !u32 {
    var val: u32 = undefined;
    try n.napi_get_value_uint32(env, self, &val).check();

    return val;
}
