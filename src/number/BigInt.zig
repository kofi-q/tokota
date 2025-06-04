//! Represents a JS `BigInt`[1] value as a sign flag and
//! an arbitrary-length slice of 64-bit little-endian "words".
//!
//! Supports conversion to/from compatible signed/unsigned Zig integer types.
//!
//! - [1] https://mdn.io/BigInt

const std = @import("std");
const builtin = @import("builtin");

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

const littleToNative = std.mem.littleToNative;
const nativeToLittle = std.mem.nativeToLittle;
const native_endian = builtin.cpu.arch.endian();

const BigInt = @This();

/// Represents the sign bit for the `BigInt`.
negative: bool,

/// The list of little-endian words representing the `BigInt` value.
words: []const Word,

/// The Node-API `BigInt` word size.
pub const Word = u64;

/// `i64` representation of a JS `BigInt`, returned from `Env.bigIntI64()`.
///
/// > #### ⚠ NOTE
/// > The `lossless` field should be checked before use, as `lossless == false`
/// indicates that the value has been truncated.
pub const I64 = struct {
    /// Indicates whether the BigInt value was converted losslessly.
    lossless: bool,
    val: i64,
};

/// `u64` representation of a JS `BigInt`, returned from `Env.bigIntU64()`.
///
/// > #### ⚠ NOTE
/// > The `lossless` field should be checked before use, as `lossless == false`
/// indicates that the value has been truncated.
pub const U64 = struct {
    /// Indicates whether the BigInt value was converted losslessly.
    lossless: bool,
    val: u64,
};

/// Error set for `BigInt.to()`.
pub const Error = error{
    /// Attempted to convert a `BigInt` to an int type of insufficient bit size.
    BigIntOverflow,

    /// Attempted to convert a negative `BigInt` to an unsigned int type.
    ExpectedUnsignedBigInt,
};

const word_bit_count: comptime_int = @bitSizeOf(Word);

/// Converts a comptime-known number of `BigInt` `Word`s to the given `ZigInt`
/// type.
///
/// - `Err.ExpectedUnsignedBigInt` is returned if attempting to convert a
/// negative `BigInt` to an unsigned integer.
///
/// - `Err.BigIntOverflow` is returned if `ZigInt` does not contain enough bits
/// to store the `BigInt` value.
pub inline fn castStatic(
    comptime ZigInt: type,
    words: *const [wordCount(ZigInt)]BigInt.Word,
    negative: bool,
) Error!ZigInt {
    const int_info = @typeInfo(ZigInt).int;
    if ((comptime int_info.signedness == .unsigned) and negative) {
        return Error.ExpectedUnsignedBigInt;
    }

    const Uint = std.meta.Int(.unsigned, wordCount(ZigInt) * word_bit_count);
    const uint = std.mem.readInt(Uint, @ptrCast(words), .little);

    if (comptime int_info.signedness == .unsigned) {
        if (uint > std.math.maxInt(ZigInt)) {
            return BigInt.Error.BigIntOverflow;
        }

        return @intCast(uint);
    }

    if (negative) {
        if (uint > std.math.maxInt(ZigInt) + 1) {
            return Error.BigIntOverflow;
        }

        return @intCast(std.math.negateCast(uint) catch unreachable);
    }

    if (uint > std.math.maxInt(ZigInt)) return Error.BigIntOverflow;

    return @intCast(uint);
}

/// Converts the given signed integer to a `BigInt`.
pub inline fn fromSigned(val: anytype) BigInt {
    const ZigInt = @TypeOf(val);

    const type_err = "Expected signed int, got `" ++ @typeName(ZigInt) ++ "`";
    const int_info = comptime switch (@typeInfo(ZigInt)) {
        .int => |int_info| switch (int_info.signedness) {
            .signed => int_info,
            else => @compileError(type_err),
        },

        else => @compileError(type_err),
    };

    const word_count = comptime wordCount(ZigInt);
    const Uint = std.meta.Int(.unsigned, word_count * word_bit_count);

    const PaddedInt = std.meta.Int(.signed, int_info.bits + 1);
    const is_negative = val < 0;
    const sign_multiplier = 1 - @as(i8, 2) * @intFromBool(is_negative);

    var big_int = fromUnsigned(@as(
        Uint,
        @intCast(@as(PaddedInt, val) * sign_multiplier),
    ));
    big_int.negative = is_negative;

    return big_int;
}

/// Converts the given unsigned integer to a `BigInt`.
pub inline fn fromUnsigned(val: anytype) BigInt {
    const ZigInt = @TypeOf(val);

    const type_err = "Expected unsigned int, got `" ++ @typeName(ZigInt) ++ "`";
    comptime switch (@typeInfo(ZigInt)) {
        .int => |int_info| switch (int_info.signedness) {
            .unsigned => {},
            else => @compileError(type_err),
        },

        else => @compileError(type_err),
    };

    const word_count = wordCount(@TypeOf(val));
    const Uint = std.meta.Int(.unsigned, word_count * word_bit_count);

    var word_buf: [word_count]Word = undefined;
    std.mem.writeInt(Uint, @ptrCast(&word_buf), val, .little);

    return .{ .negative = false, .words = word_buf[0..] };
}

pub fn signedness(comptime ZigInt: type) std.builtin.Signedness {
    return switch (@typeInfo(ZigInt)) {
        .int => |int| int.signedness,
        else => @compileError(
            "Expected int type, got `" ++ @typeName(ZigInt) ++ "`",
        ),
    };
}

/// Converts this `BigInt` to the given `ZigInt` type.
///
/// - `Error.ExpectedUnsignedBigInt` is returned if attempting to convert a
/// negative `BigInt` to an unsigned integer.
///
/// - `Error.BigIntOverflow` is returned if `ZigInt` does not contain enough bits
/// to store the `BigInt` value.
pub fn to(self: *const BigInt, comptime ZigInt: type) Error!ZigInt {
    const target_word_count = wordCount(ZigInt);

    if (target_word_count < self.words.len) return Error.BigIntOverflow;

    var buf: [target_word_count]BigInt.Word = undefined;
    @memcpy(buf[0..self.words.len], self.words);
    @memset(buf[self.words.len..], 0);

    return BigInt.castStatic(ZigInt, &buf, self.negative);
}

/// Creates a newly allocated JS `BigInt` value from this `BigInt`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_bigint_words
pub fn toJs(self: *const BigInt, env: Env) !Val {
    var ptr: ?Val = null;
    try n.napi_create_bigint_words(
        env,
        @intFromBool(self.negative),
        self.words.len,
        self.words.ptr,
        &ptr,
    ).check();

    return ptr.?;
}

/// Minimum number of BigInt `Word`s needed to represent the given integer type.
pub fn wordCount(comptime T: type) comptime_int {
    const unsigned_bit_count = switch (@typeInfo(T)) {
        .int => |int_info| int_info.bits,
        else => @compileError(
            "Expected int type, got `" ++ @typeName(T) ++ "`.",
        ),
    };

    return @divFloor(unsigned_bit_count - 1, word_bit_count) + 1;
}

test to {
    const positive_bigint = BigInt{ .negative = false, .words = &.{
        nativeToLittle(Word, 0xf00df00df00df00d),
        nativeToLittle(Word, 0xCafeCafeCafeCafe),
    } };
    try std.testing.expectEqual(
        0xCafeCafeCafeCafe_f00df00df00df00d,
        positive_bigint.to(u128),
    );
    try std.testing.expectError(Error.BigIntOverflow, positive_bigint.to(Word));
    try std.testing.expectError(Error.BigIntOverflow, positive_bigint.to(i64));
    try std.testing.expectError(Error.BigIntOverflow, positive_bigint.to(u64));

    const negative_bigint = BigInt{ .negative = true, .words = &.{
        nativeToLittle(Word, 0xf00df00df00df00d),
        nativeToLittle(Word, 0xCafeCafeCafeCafe),
    } };
    try std.testing.expectEqual(
        -0xCafeCafeCafeCafe_f00df00df00df00d,
        negative_bigint.to(i129),
    );
    try std.testing.expectError(
        Error.ExpectedUnsignedBigInt,
        negative_bigint.to(u128),
    );
    try std.testing.expectError(Error.BigIntOverflow, negative_bigint.to(i64));
    try std.testing.expectError(Error.BigIntOverflow, negative_bigint.to(u64));
}

test fromSigned {
    // Within word boundary:
    try std.testing.expectEqualDeep(
        BigInt{
            .negative = true,
            .words = &.{
                nativeToLittle(Word, 0x1009100910091009),
                nativeToLittle(Word, 0xbeadbeadbead),
                0,
            },
        },
        BigInt.fromSigned(@as(i129, -0xbeadbeadbead_1009100910091009)),
    );

    // Edge word boundary:
    try std.testing.expectEqualDeep(
        BigInt{
            .negative = true,
            .words = &.{
                nativeToLittle(Word, std.math.maxInt(Word)),
                nativeToLittle(Word, std.math.maxInt(Word)),
                0,
            },
        },
        BigInt.fromSigned(@as(i129, -std.math.maxInt(u128))),
    );

    // Just past word boundary:
    try std.testing.expectEqualDeep(
        BigInt{
            .negative = true,
            .words = &.{
                0,
                0,
                nativeToLittle(Word, 0x1),
            },
        },
        BigInt.fromSigned(@as(i129, std.math.minInt(i129))),
    );

    // Positive, signed BigInt
    try std.testing.expectEqualDeep(
        BigInt{
            .negative = false,
            .words = &.{
                nativeToLittle(Word, 0x1009100910091009),
                nativeToLittle(Word, 0xbeadbeadbeadbead),
                0,
            },
        },
        BigInt.fromSigned(@as(i129, 0xbeadbeadbeadbead_1009100910091009)),
    );
}

test fromUnsigned {
    // Within word boundary:
    try std.testing.expectEqualDeep(
        BigInt{
            .negative = false,
            .words = &.{
                nativeToLittle(Word, 0x1009100910091009),
                nativeToLittle(Word, 0xbeadbeadbead),
            },
        },
        BigInt.fromUnsigned(@as(u128, 0xbeadbeadbead_1009100910091009)),
    );

    // Edge of word boundary:
    try std.testing.expectEqualDeep(
        BigInt{
            .negative = false,
            .words = &.{
                nativeToLittle(Word, std.math.maxInt(Word)),
                nativeToLittle(Word, std.math.maxInt(Word)),
            },
        },
        BigInt.fromUnsigned(@as(u128, std.math.maxInt(u128))),
    );

    // Just past word boundary:
    try std.testing.expectEqualDeep(
        BigInt{
            .negative = false,
            .words = &.{
                0,
                0,
                nativeToLittle(Word, 1),
            },
        },
        BigInt.fromUnsigned(@as(u129, std.math.maxInt(u128) + 1)),
    );
}
