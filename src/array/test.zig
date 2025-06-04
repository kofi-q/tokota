const std = @import("std");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModuleWithInit(@This(), init);
}

fn init(env: t.Env, exports: t.Val) !t.Val {
    _ = try env.addCleanup({}, deinit);
    return exports;
}

fn deinit() !void {
    return switch (dba.deinit()) {
        .ok => {},
        .leak => t.panic("Memory leak detected", null),
    };
}

pub fn arrayCreateAndSet(call: t.Call) !t.Array {
    const allo = dba.allocator();
    const arg_count = try call.argCount();
    const arg_buf = try allo.alloc(t.Val, arg_count);
    defer allo.free(arg_buf);

    const args = try call.argsBuf(arg_buf);

    const array = try call.env.array();
    for (0..args.len) |i| try array.set(i, args[i]);

    return array;
}

pub fn arrayCreateWithLength(call: t.Call, len: u32) !t.Array {
    return call.env.arrayN(len);
}

pub fn arrayFromZigArray(arg1: u32, arg2: u32, arg3: u32) [3]u32 {
    return [_]u32{ arg1, arg2, arg3 };
}

pub fn arrayFromZigArrayMixed(arg1: t.Val, arg2: t.Val, arg3: t.Val) [3]t.Val {
    return [_]t.Val{ arg1, arg2, arg3 };
}

pub fn arrayFromTuple(
    num_val: u8,
    bool_val: bool,
    str_val: t.Val,
) struct { u8, bool, t.Val } {
    return .{ num_val, bool_val, str_val };
}

pub fn arrayFromSlice(arg1: u32, arg2: u32, arg3: u32) []u32 {
    var buf_slice: [3]u32 = undefined;
    buf_slice = [_]u32{ arg1, arg2, arg3 };

    return buf_slice[0..];
}

pub fn arrayFromSliceMixed(arg1: t.Val, arg2: t.Val, arg3: t.Val) []t.Val {
    var buf_slice_mixed: [3]t.Val = undefined;
    buf_slice_mixed = [_]t.Val{ arg1, arg2, arg3 };

    return buf_slice_mixed[0..];
}

pub fn arrayDelete(array: t.Array, index: u32) !bool {
    return array.delete(index);
}

pub fn arrayGet(array: t.Array, index: u32) !t.Val {
    return array.get(index);
}

pub fn arrayGetAsNativeStr(array: t.Array, index: u32) !t.TinyStr(8) {
    return array.getT(index, t.TinyStr(8));
}

pub fn arrayGetAsNativeStrOpt(array: t.Array, index: u32) !?t.TinyStr(8) {
    return array.getT(index, ?t.TinyStr(8));
}

pub fn arrayIsSet(array: t.Array, index: u32) !bool {
    return array.isSet(index);
}

pub fn arrayLength(array: t.Array) !u32 {
    return @intCast(try array.len());
}

pub fn isArray(call: t.Call, arg: t.Val) !bool {
    return arg.isArray(call.env);
}
