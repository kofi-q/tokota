//! `Env` API methods for creating JS number values.

const BigInt = @import("BigInt.zig");
const Env = @import("../root.zig").Env;
const int_safe_min = @import("../root.zig").int_safe_min;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// Returns a newly allocated JS [BigInt](https://mdn.io/BigInt) with the
/// given integer value.
///
/// The integer is first split into a list of little-endian 64-bit words. For
/// single-word `BigInt`s, it may be more convenient/performant to use
/// `bigIntI64()` or `bigIntU64()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_bigint_words
pub fn bigInt(self: Env, int: anytype) !Val {
    const big_int: BigInt = switch (comptime BigInt.signedness(@TypeOf(int))) {
        .signed => .fromSigned(int),
        .unsigned => .fromUnsigned(int),
    };

    return big_int.toJs(self);
}

/// Returns a newly allocated JS [BigInt](https://mdn.io/BigInt) with the
/// given `i64` value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_bigint_int64
pub fn bigIntI64(self: Env, int: i64) !Val {
    var ptr: ?Val = null;
    try n.napi_create_bigint_int64(self, int, &ptr).check();

    return ptr.?;
}

/// Returns a newly allocated JS [BigInt](https://mdn.io/BigInt) with the
/// given `u64` value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_bigint_uint64
pub fn bigIntU64(self: Env, int: u64) !Val {
    var ptr: ?Val = null;
    try n.napi_create_bigint_uint64(self, int, &ptr).check();

    return ptr.?;
}

/// Returns a newly allocated JS `Number` value with the given `f64` value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_double
pub fn float64(self: Env, val: f64) !Val {
    var ptr: ?Val = null;
    try n.napi_create_double(self, val, &ptr).check();

    return ptr.?;
}

/// Returns a newly allocated JS `Number` value with the given `i32` value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_int32
pub fn int32(self: Env, val: i32) !Val {
    var ptr: ?Val = null;
    try n.napi_create_int32(self, val, &ptr).check();

    return ptr.?;
}

/// Returns a newly allocated JS `Number` value with the given `i54`, which
/// represents the safe integer range of the JS `Number` type.
///
/// Since `i54` includes `int_safe_min - 1`, a runtime check is performed to
/// verify that `val` doesn't fall outside the safe integer range - returns
/// `error.IntegerOutOfRange` otherwise.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_int64
pub fn int54(self: Env, val: i54) !Val {
    if (val < int_safe_min) return error.IntegerOutOfRange;

    var ptr: ?Val = null;
    try n.napi_create_int64(self, val, &ptr).check();

    return ptr.?;
}

/// Returns a newly allocated JS `Number` value with the given `u32` value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_uint32
pub fn uint32(self: Env, val: u32) !Val {
    var ptr: ?Val = null;
    try n.napi_create_uint32(self, val, &ptr).check();

    return ptr.?;
}

/// Returns a newly allocated JS `Number` value with the given `u53` value.
///
/// `u53` is used to represent the safe positive integer limit of the JS
/// `Number` type.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_int64
pub fn uint53(self: Env, val: u53) !Val {
    var ptr: ?Val = null;
    try n.napi_create_int64(self, val, &ptr).check();

    return ptr.?;
}
