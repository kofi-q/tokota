const std = @import("std");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub const tokota_options = t.Options{
    .napi_version = .v9,
};

comptime {
    t.exportModuleWithInit(@This(), moduleInit);
}

fn moduleInit(_: t.Env, exports: t.Val) !t.Val {
    std.debug.assert(
        std.mem.eql(u8, t.options.lib_name, tokota_options.lib_name),
    );
    std.debug.assert(t.options.napi_version == tokota_options.napi_version);

    return exports;
}

fn moduleDeinit() !void {
    return switch (dba.deinit()) {
        .ok => {},
        .leak => t.panic("Memory leak detected", null),
    };
}

pub fn nodeVersion(call: t.Call) !*const t.NodeVersion {
    return call.env.nodeVersion();
}

pub fn runScript(call: t.Call, script: t.TinyStr(128)) !t.Val {
    return call.env.run(script.slice());
}

pub fn moduleFileName(call: t.Call) ![*:0]const u8 {
    return call.env.moduleFileName();
}

pub fn returnString() []const u8 {
    return "foo";
}

pub fn returnStringNonConst() []u8 {
    return @constCast("foo");
}

pub fn returnStringU8ArrayPtr() !*const [3]u8 {
    return "foo";
}

pub fn returnStringNullTerminated() [:0]const u8 {
    return "foo";
}

pub fn returnStringNullTerminatedNonConst() [:0]u8 {
    return @constCast("foo");
}

pub fn returnStringNullTerminatedPtr() [*:0]const u8 {
    return "foo";
}

pub fn returnStringNullTerminatedPtrNonConst() [*:0]u8 {
    return @ptrCast(@constCast("foo"));
}

pub fn returnSliceOfStrings(
    a: t.TinyStr(3),
    b: t.TinyStr(3),
    c: t.TinyStr(3),
) []const []const u8 {
    return &.{ a.slice(), b.slice(), c.slice() };
}

pub fn returnTinyStr(str: t.TinyStr(8)) t.TinyStr(8) {
    return str;
}

pub fn returnSymbol(symbol: t.Symbol) t.Symbol {
    return symbol;
}

pub fn returnTokotaArray(array: t.Array) t.Array {
    return array;
}

const zig_array = [2]u16{
    0xcafe,
    0xf00d,
};

pub fn returnZigArray() [2]u16 {
    return zig_array;
}

pub fn returnZigArrayU8() [3]u8 {
    return [_]u8{ 128, 0, 255 };
}

pub fn returnZigArrayPtr() *const [2]u16 {
    return &zig_array;
}

const Tuple = struct { u32, bool };
const zig_tuple: Tuple = .{ 42, true };

pub fn returnZigTuple(vals: Tuple) Tuple {
    return vals;
}

pub fn returnZigTuplePtr() *const Tuple {
    return &zig_tuple;
}

pub fn returnArrayBuffer(buffer: t.ArrayBuffer) t.ArrayBuffer {
    return buffer;
}

pub fn returnBigInt() t.BigInt {
    return t.BigInt{
        .negative = true,
        .words = &.{
            0xcafe_f00d_0000_0000,
            0xc001_d00d_0000_0000,
        },
    };
}

pub fn returnBool(value: bool) !bool {
    return value;
}

pub fn returnDate(date: t.Date) !t.Date {
    return date;
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn returnZigFn() @TypeOf(add) {
    return add;
}

pub fn returnFn(function: t.Fn) t.Fn {
    return function;
}

const ClosureData = struct { foo: u32 };
const Closure = t.Closure(closureFn, *ClosureData);

pub fn returnClosure() !Closure {
    const data = try dba.allocator().create(ClosureData);
    data.* = .{ .foo = 42 };

    return .init(data, .with(closureDeinit));
}

fn closureFn(call: t.CallT(*ClosureData)) !?*ClosureData {
    return call.data();
}

fn closureDeinit(data: *ClosureData, env: t.Env) !void {
    dba.allocator().destroy(data);

    // Looks like this finalizer is the last cleanup to run, regardless of the
    // order in which cleanups are declared, so scheduling the memory leak
    // check here instead of in a top-level `Env.addCleanup()`.
    _ = try env.addCleanup({}, moduleDeinit);
}

pub fn returnBuffer(buffer: t.Buffer) t.Buffer {
    return buffer;
}

pub fn returnDataView(data_view: t.DataView) t.DataView {
    return data_view;
}

pub fn returnTypedArray(array: t.TypedArray(.u32)) t.TypedArray(.u32) {
    return array;
}

pub fn returnFloatComptime() comptime_float {
    return 3.142;
}

pub fn returnFloatF32(val: f64) f32 {
    return @floatCast(val);
}

pub fn returnFloatF64(val: f64) f64 {
    return val;
}

pub fn returnIntComptimeMaxSafe() comptime_int {
    return t.int_safe_max;
}

pub fn returnIntComptimeMinSafe() comptime_int {
    return t.int_safe_min;
}

pub fn returnIntI8(val: i8) i8 {
    return val;
}

pub fn returnIntI16(val: i16) i16 {
    return val;
}

pub fn returnIntI32(val: i32) i32 {
    return val;
}

pub const I53_MAX: i53 = std.math.maxInt(i53);
pub const I53_MIN: i53 = std.math.minInt(i53);

pub fn returnIntI53(val: i53) !i53 {
    return val;
}

pub fn returnIntI54(call: t.Call, val: i54) !t.Val {
    return call.env.int54(val);
}

pub fn returnIntI54FromF64(call: t.Call, val: f64) !t.Val {
    return call.env.int54(@intFromFloat(val));
}

pub fn returnIntI64(val: i64) i64 {
    return val;
}

pub const I128_MAX: i128 = std.math.maxInt(i128);
pub const I128_MIN: i128 = std.math.minInt(i128);

pub fn returnIntI128(val: i128) i128 {
    return val;
}

pub fn returnIntU8(val: u8) u8 {
    return val;
}

pub fn returnIntU16(val: u16) u16 {
    return val;
}

pub fn returnIntU32(val: u32) u32 {
    return val;
}

pub fn returnIntU53(val: u53) u53 {
    return val;
}

pub fn returnIntU64(val: u64) u64 {
    return val;
}

pub const U128_MAX: u128 = std.math.maxInt(u128);

pub fn returnIntU128(val: u128) u128 {
    return val;
}

pub fn returnObject(object: t.Object) t.Object {
    return object;
}

pub fn returnObjectOptional(object: ?t.Object) ?t.Object {
    return object;
}

pub fn returnPromise(promise: t.Promise) t.Promise {
    return promise;
}

pub fn returnVoid() void {
    return {};
}

const PuppyShelter = struct {
    const unexportedConst = "ignore me";

    pub const capacity: u32 = 42;

    pub fn adopt(name: t.TinyStr(16)) t.TinyStr(16) {
        return name;
    }

    fn unexportedFn(call: t.Call) void {
        call.env.throwErrCode(error.EmployeesOnly, "This area is closed.");
    }
};

pub fn returnStructType() type {
    return PuppyShelter;
}

pub fn returnStructTypeOptional() ?type {
    return null;
}

const PuppyApiWithData = t.Api([*:0]const u8, struct {
    const unexportedConst = "ignore me";

    pub const capacity: u32 = 42;

    const Call = t.CallT([*:0]const u8);

    pub fn adopt(name: t.TinyStr(16)) t.TinyStr(16) {
        return name;
    }

    pub fn attachedData(call: Call) ![*:0]const u8 {
        return try call.data() orelse return error.MissingMethodData;
    }

    pub fn hasAttachedData(call: Call) !bool {
        const data = try call.data();
        return data != null;
    }

    fn unexportedFn(call: Call) void {
        call.env.throwErrCode(error.EmployeesOnly, "This area is closed.");
    }
});

pub fn returnTokotaApi(data: t.TinyStr(16)) !PuppyApiWithData {
    const native_data = try dba.allocator().dupeZ(u8, data.slice());

    return .init(
        native_data.ptr,
        .with(deinitApiData),
    );
}

pub fn returnTokotaApiOptional() ?PuppyApiWithData {
    return null;
}

fn deinitApiData(data: [*:0]const u8, _: t.Env) !void {
    const str = std.mem.span(data);
    dba.allocator().free(str);
}

const Weather = struct {
    airQuality: ?u32,
    condition: enum { cloudy, sunny, windy },
    forecast: t.TinyStr(64),
    humidity: f64,
    rainExpected: bool,
    tempC: u8,
};

pub fn returnStructInstance(weather: Weather) Weather {
    return weather;
}

pub fn returnStructInstanceOptional(weather: ?Weather) ?Weather {
    return weather;
}

const LogLevel = enum { warn, err, catastrophic };

pub fn returnEnumType() type {
    return LogLevel;
}

pub fn returnEnumValue(log_level: LogLevel) LogLevel {
    return log_level;
}

pub fn returnEnumValueOptional(log_level: ?LogLevel) ?LogLevel {
    return log_level;
}

const LogLevelString = t.enums.ToStringEnum(LogLevel);

pub fn returnStringEnumValue(log_level: LogLevelString) LogLevelString {
    return log_level;
}

pub fn returnStringEnumValueOptional(
    log_level: ?LogLevelString,
) ?LogLevelString {
    return log_level;
}

const Note = enum {
    DO,
    RE,
    MI,

    const StringEnumImpl = t.enums.StringEnumImpl(@This());

    pub const fromJs = StringEnumImpl.fromJs;
    pub const toJs = StringEnumImpl.toJs;
};

pub fn returnStringEnumImplValue(note: Note) Note {
    return note;
}

const Abilities = packed struct(u16) {
    bugless_code: bool = false,
    comedic_timing: bool = false,
    flight: bool = false,
    invisibility: bool = false,
    lactose_tolerance: bool = false,
    nonchalance: bool = false,
    super_strength: bool = false,
    _7: u6 = 0,
    telepathy: bool = false,
    _: u2 = 0,
};

pub fn returnBitFlagsAsEnum() type {
    return t.enums.FromBitFlags(Abilities, .{
        .extra_fields = &.{
            .{ "powerless", .{} },
        },
    });
}

pub fn returnPackedStructInstance(abilities: Abilities) Abilities {
    return abilities;
}

pub fn returnPackedStructInstanceOptional(abilities: ?Abilities) ?Abilities {
    return abilities;
}
