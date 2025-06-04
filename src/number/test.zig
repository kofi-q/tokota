const std = @import("std");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModule(@This());
}

pub const BigInts = struct {
    pub fn twoWordMin(call: t.Call) !t.Val {
        return call.env.bigInt(@as(i129, -std.math.maxInt(u128)));
    }

    pub fn twoWordMax(call: t.Call) !t.Val {
        return call.env.bigInt(@as(u128, std.math.maxInt(u128)));
    }

    pub fn i64Min(call: t.Call) !t.Val {
        return call.env.bigIntI64(std.math.minInt(i64));
    }

    pub fn u64Max(call: t.Call) !t.Val {
        return call.env.bigIntU64(std.math.maxInt(u64));
    }

    pub fn roundtripI64(call: t.Call, bigint_i64: t.BigInt.I64) !t.Object {
        return call.env.objectFrom(bigint_i64);
    }

    pub fn roundtripU64(call: t.Call, bigint_u64: t.BigInt.U64) !t.Object {
        return call.env.objectFrom(bigint_u64);
    }

    pub fn roundtripWordsU128(call: t.Call, arg_as_u128: u128) !t.Val {
        return call.env.bigInt(arg_as_u128);
    }

    pub fn roundtripWordsI128(call: t.Call, arg_as_i128: i128) !t.Val {
        return call.env.bigInt(arg_as_i128);
    }

    pub const U155_MAX: u155 = std.math.maxInt(u155);
    pub const I155_MAX: i155 = std.math.maxInt(i155);
    pub const I155_MIN: i155 = std.math.minInt(i155);

    pub fn roundtripWordsU155(call: t.Call, arg_as_u155: u155) !t.Val {
        return call.env.bigInt(arg_as_u155);
    }

    pub fn roundtripWordsI155(call: t.Call, arg_as_i155: i155) !t.Val {
        return call.env.bigInt(arg_as_i155);
    }

    pub fn roundtripWordsBuf(call: t.Call, input: t.Val) !t.Val {
        var buf: [2]t.BigInt.Word = undefined;
        var big_int = try input.bigIntBuf(call.env, &buf);

        return big_int.toJs(call.env);
    }
};

pub const Floats = struct {
    pub fn coerce(call: t.Call, input: t.Val) !f64 {
        const as_number = try input.numberCoerce(call.env);
        return as_number.float64(call.env);
    }

    pub fn roundtripF64(input: f64) !f64 {
        return input;
    }
};

pub const Ints = struct {
    pub fn coerce(call: t.Call, input: t.Val) !f64 {
        const as_number = try input.numberCoerce(call.env);
        return as_number.float64(call.env);
    }

    pub fn i32Min() i32 {
        return std.math.minInt(i32);
    }

    pub fn u32Max() u32 {
        return std.math.maxInt(u32);
    }

    pub fn roundtripI32(input: i32) !i32 {
        return input;
    }

    pub fn roundtripU32(input: u32) !u32 {
        return input;
    }

    pub fn roundtripIntSafeMinMax(input: i54) !f64 {
        return @floatFromInt(input);
    }
};
