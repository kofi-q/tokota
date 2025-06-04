const std = @import("std");

const Array = @import("root.zig").Array;
const ArrayBuffer = @import("root.zig").ArrayBuffer;
const Buffer = @import("root.zig").Buffer;
const Class = @import("root.zig").Class;
const DataView = @import("root.zig").DataView;
const Date = @import("root.zig").Date;
const BigInt = @import("root.zig").BigInt;
const int_safe_min = @import("root.zig").int_safe_min;
const Env = @import("root.zig").Env;
const Err = @import("root.zig").Err;
const Fn = @import("root.zig").Fn;
const n = @import("napi.zig");
const Object = @import("root.zig").Object;
const Promise = @import("root.zig").Promise;
const Symbol = @import("root.zig").Symbol;

/// JS value types returned by `Val.typeOf()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_valuetype
pub const ValType = enum(c_int) {
    big_int = 9,
    boolean = 2,
    external = 8,
    function = 7,
    null = 1,
    number = 3,
    object = 6,
    string = 4,
    symbol = 5,
    undefined = 0,
};

/// A handle to JS value of any type. Native values can be extracted with one of
/// the provided type methods (e.g. `Val.string()`), when the type is known.
/// Types can be determined with `Val.typeOf()` or with any of the more specific
/// `is<Type>()` convenience methods.
///
/// `Val`s can either be received (via arguments to addon functions), or created
/// via methods on the `Env` object.
///
/// > #### ⚠ NOTE
/// > `Val` handles are only valid for the duration of the scope within
/// which they are created - usually the scope of an addon callback function.
/// Handles that need to be reference later on an another thread or in another
/// callback must be referenced first (e.g. `Object.ref()`, `ArrayBuffer.ref()`).
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_value
pub const Val = *const NapiVal;
const NapiVal = opaque {
    const ext_array = @import("array/Val.zig");
    const ext_array_buffer = @import("array_buffer/Val.zig");
    const ext_async = @import("async/Val.zig");
    const ext_date = @import("date/Val.zig");
    const ext_error = @import("error/Val.zig");
    const ext_function = @import("function/Val.zig");
    const ext_global = @import("global/Val.zig");
    const ext_heap = @import("heap/Val.zig");
    const ext_lifetime = @import("lifetime/Val.zig");
    const ext_number = @import("number/Val.zig");
    const ext_object = @import("object/Val.zig");
    const ext_string = @import("string/Val.zig");

    pub const array = ext_array.array;
    pub const arrayBuffer = ext_array_buffer.arrayBuffer;
    pub const bigInt = ext_number.bigInt;
    pub const bigIntBuf = ext_number.bigIntBuf;
    pub const bigIntI64 = ext_number.bigIntI64;
    pub const bigIntU64 = ext_number.bigIntU64;
    pub const bigIntWordCount = ext_number.bigIntWordCount;
    pub const boolCoerce = ext_global.boolCoerce;
    pub const boolean = ext_global.boolean;
    pub const buffer = ext_array_buffer.buffer;
    pub const class = ext_object.class;
    pub const dataView = ext_array_buffer.dataView;
    pub const date = ext_date.date;
    pub const external = ext_heap.external;
    pub const float64 = ext_number.float64;
    pub const function = ext_function.function;
    pub const functionTyped = ext_function.functionTyped;
    pub const instanceOf = ext_object.instanceOf;
    pub const isArray = ext_array.isArray;
    pub const isArrayBuffer = ext_array_buffer.isArrayBuffer;
    pub const isBuffer = ext_array_buffer.isBuffer;
    pub const isDataView = ext_array_buffer.isDataView;
    pub const isDate = ext_date.isDate;
    pub const isError = ext_error.isError;
    pub const isNullOrUndefined = ext_global.isNullOrUndefined;
    pub const isPromise = ext_async.isPromise;
    pub const isTypedArray = ext_array_buffer.isTypedArray;
    pub const numberCoerce = ext_number.numberCoerce;
    pub const object = ext_object.object;
    pub const objectCoerce = ext_object.objectCoerce;
    pub const promise = ext_async.promise;
    pub const ref = ext_lifetime.ref;
    pub const string = ext_string.string;
    pub const stringAlloc = ext_string.stringAlloc;
    pub const stringBuf = ext_string.stringBuf;
    pub const stringCoerce = ext_string.stringCoerce;
    pub const stringLen = ext_string.stringLen;
    pub const strLatin1 = ext_string.strLatin1;
    pub const strLatin1Alloc = ext_string.strLatin1Alloc;
    pub const strLatin1Buf = ext_string.strLatin1Buf;
    pub const strLatin1Len = ext_string.strLatin1Len;
    pub const strUtf16 = ext_string.strUtf16;
    pub const strUtf16Alloc = ext_string.strUtf16Alloc;
    pub const strUtf16Buf = ext_string.strUtf16Buf;
    pub const strUtf16Len = ext_string.strUtf16Len;
    pub const symbol = ext_global.symbol;
    pub const typedArray = ext_array_buffer.typedArray;
    pub const unsafeI32 = ext_number.unsafeI32;
    pub const unsafeU32 = ext_number.unsafeU32;

    /// https://nodejs.org/docs/latest/api/n-api.html#napi_strict_equals
    pub fn eqlStrict(self: Val, other: Val, env: Env) !bool {
        var result: bool = undefined;
        try n.napi_strict_equals(env, self, other, &result).check();

        return result;
    }

    /// Converts the JS value to a given Zig type.
    ///
    /// Performs runtime JS type and/or range checks, where needed/feasible and
    /// returns errors for invalid JS types/values.
    ///
    /// Intended for use internally for Node-API callback argument inference,
    /// but may be externally useful in some cases (e.g. writing a custom
    /// `fromJs()` conversion for a complex type).
    pub inline fn to(self: Val, env: Env, comptime T: type) !T {
        var val_type: ?ValType = null;

        const Payload, const is_optional = comptime switch (@typeInfo(T)) {
            .optional => |opt_info| .{ opt_info.child, true },
            else => .{ T, false },
        };

        if (comptime is_optional) {
            val_type = try self.typeOf(env);

            switch (val_type.?) {
                .null, .undefined => return null,
                else => {},
            }
        }

        const TypeOrConverter = comptime switch (@typeInfo(Payload)) {
            .@"enum" => blk: {
                if (@hasDecl(Payload, "fromJs")) break :blk Payload;
                break :blk EnumConverter(Payload);
            },

            .pointer => |p| switch (p.size) {
                .one => if (@hasDecl(p.child, "fromJs")) p.child else Payload,
                else => Payload,
            },

            .@"struct" => |s| switch (s.layout) {
                .@"packed" => if (@hasDecl(Payload, "fromJs"))
                    Payload
                else
                    PackedStructConverter(Payload),

                else => Payload,
            },

            else => Payload,
        };

        return switch (comptime TypeOrConverter) {
            Array => if (try self.isArray(env)) .{
                .env = env,
                .ptr = self,
            } else Err.ArrayExpected,

            ArrayBuffer => self.arrayBuffer(env) catch |err| switch (err) {
                Err.InvalidArg => Err.ArrayBufferExpected, // node, deno
                else => err,
            },

            BigInt.I64 => try self.bigIntI64(env),
            BigInt.U64 => try self.bigIntU64(env),

            bool => try self.boolean(env),

            Buffer => self.buffer(env) catch |e| switch (e) {
                Err.InvalidArg, // node, deno
                Err.ObjectExpected, // bun
                => error.BufferExpected,

                else => e,
            },

            // Best available validation without constructing an instance.
            Class => switch (val_type orelse try self.typeOf(env)) {
                .function => .{ .env = env, .ptr = self },
                else => error.ClassExpected,
            },

            DataView => self.dataView(env) catch |e| switch (e) {
                Err.InvalidArg, // node, deno
                Err.ObjectExpected, // bun
                => error.DataViewExpected,

                else => e,
            },

            Date => try self.date(env),

            f32 => @compileError(
                \\Inferred JS type conversion to f32 is unsupported, as it may
                \\result in incorrect values/precision loss. Consider using f64
                \\instead and safely convert to f32, if necessary.
                \\
                \\(❓) You may need to build with the `-freference-trace`
                \\     flag to find the relevant source location.
            ),
            f64 => try self.float64(env),

            Fn => switch (val_type orelse try self.typeOf(env)) {
                .function => .{ .env = env, .ptr = self },
                else => Err.FunctionExpected,
            },

            Object => switch (val_type orelse try self.typeOf(env)) {
                .object => .{ .env = env, .ptr = self },
                else => Err.ObjectExpected,
            },

            Promise => if (try self.isPromise(env)) .{
                .env = env,
                .ptr = self,
            } else error.PromiseExpected,

            // [TODO] Any validation we can do here?
            Symbol => .{
                .env = env,
                .ptr = self,
            },

            Val => self,

            void => {},

            else => switch (comptime @typeInfo(TypeOrConverter)) {
                .@"struct" => |struct_info| blk: {
                    if (comptime @hasDecl(TypeOrConverter, "fromJs")) {
                        break :blk try @call(
                            .always_inline,
                            TypeOrConverter.fromJs,
                            .{ env, self },
                        );
                    }

                    break :blk switch (val_type orelse try self.typeOf(env)) {
                        .object => try @call(.always_inline, Object.to, .{
                            self.object(env), TypeOrConverter,
                        }),

                        else => comptime if (struct_info.is_tuple)
                            Err.ArrayExpected
                        else
                            Err.ObjectExpected,
                    };
                },

                .@"enum",
                .@"opaque",
                .@"union",
                => if (@hasDecl(TypeOrConverter, "fromJs")) try @call(
                    .always_inline,
                    TypeOrConverter.fromJs,
                    .{ env, self },
                ) else @compileError(std.fmt.comptimePrint(
                    \\Cannot infer JS type conversion to `{[0]s}`. Options:
                    \\  - Add a `pub fn fromJs(Env, Val) !{[0]s}` method.
                    \\  - Use `Val` directly and explicitly convert to the
                    \\    desired type (or unwrap it via `Object.unwrap()`,
                    \\    if that's the intention).
                    \\
                    \\(❓) You may need to build with the `-freference-trace`
                    \\     flag to find the relevant source location.
                , .{@typeName(TypeOrConverter)})),

                .int => try self.int(TypeOrConverter, env),

                .pointer => |p| switch (p.size) {
                    .one => @compileError(std.fmt.comptimePrint(
                        \\Cannot infer JS type conversion to `{[0]s}`. Options:
                        \\  - Add a `pub fn fromJs(Env, Val) !{[0]s}` method.
                        \\  - Use `Val` directly and explicitly convert to the
                        \\    desired type (or unwrap it via `Object.unwrap()`,
                        \\    if that's the intention).
                        \\
                        \\(❓) You may need to build with the `-freference-trace`
                        \\     flag to find the relevant source location.
                    , .{@typeName(TypeOrConverter)})),

                    else => @compileError(std.fmt.comptimePrint(
                        \\Cannot infer JS type conversion to `{[0]s}`.  Options:
                        \\  - Use `Val` directly and explicitly convert to the
                        \\    desired type (or unwrap it via `Object.unwrap()`,
                        \\    if that's the intention).
                        \\  - Wrap `{[0]s}` in a type, T, with a
                        \\    `pub fn fromJs(Env, Val) !T` method.
                        \\
                        \\(❓) You may need to build with the `-freference-trace`
                        \\     flag to find the relevant source location.
                    , .{@typeName(TypeOrConverter)})),
                },

                else => @compileError(std.fmt.comptimePrint(
                    \\Cannot infer JS type conversion to `{[0]s}`.  Options:
                    \\  - Use `Val` directly and explicitly convert to the
                    \\    desired type (or unwrap it via `Object.unwrap()`,
                    \\    if that's the intention).
                    \\  - Wrap `{[0]s}` in a type, T, with a
                    \\    `pub fn fromJs(Env, Val) !T` method.
                    \\
                    \\(❓) You may need to build with the `-freference-trace`
                    \\     flag to find the relevant source location.
                , .{@typeName(TypeOrConverter)})),
            },
        };
    }

    inline fn int(self: Val, comptime Int: type, env: Env) !Int {
        const info = @typeInfo(Int).int;

        return switch (comptime info.signedness) {
            .signed => blk: {
                if (comptime info.bits > 54) break :blk self.bigInt(env, Int);

                const num = try self.float64(env);
                if (@floor(num) != num) return error.IntegerExpected;

                const max = std.math.maxInt(Int);
                const min = comptime if (Int == i54)
                    int_safe_min
                else
                    std.math.minInt(Int);

                if (num < min or num > max) return error.IntegerOutOfRange;

                break :blk @intFromFloat(num);
            },

            .unsigned => blk: {
                if (comptime info.bits > 53) break :blk self.bigInt(env, Int);

                const num = try self.float64(env);
                if (@floor(num) != num) return error.IntegerExpected;

                const max = std.math.maxInt(Int);
                if (num < 0 or num > max) return error.IntegerOutOfRange;

                break :blk @intFromFloat(num);
            },
        };
    }

    /// https://nodejs.org/docs/latest/api/n-api.html#napi_typeof
    pub inline fn typeOf(self: Val, env: Env) !ValType {
        var result: ValType = undefined;
        try n.napi_typeof(env, self, &result).check();

        return result;
    }
};

fn EnumConverter(comptime Enum: type) type {
    const TagInt = @typeInfo(Enum).@"enum".tag_type;

    if (@typeInfo(TagInt).int.bits > 53) @compileError(std.fmt.comptimePrint(
        \\Cannot infer JS type conversion to `{[0]s}`
        \\Inferred conversion is not supported for enums with
        \\bit size > 53 (to stay below the JS safe integer limit).
        \\Consider adding an explicit `fn fromJs(Env, Val)` decl instead, or
        \\changing the enum tag type, if feasible.
        \\
        \\(❓) You may need to build with the `-freference-trace`
        \\     flag to find the relevant source location.
    , .{@typeName(Enum)}));

    return struct {
        pub fn fromJs(env: Env, val: Val) !Enum {
            return std.meta.intToEnum(
                Enum,
                val.int(TagInt, env) catch |err| return switch (err) {
                    error.IntegerOutOfRange => error.InvalidEnumTag,
                    else => err,
                },
            );
        }
    };
}

fn PackedStructConverter(comptime PackedStruct: type) type {
    const Int = @typeInfo(PackedStruct).@"struct".backing_integer.?;

    if (@typeInfo(Int).int.bits > 53) @compileError(std.fmt.comptimePrint(
        \\Cannot infer JS type conversion to `{[0]s}`
        \\Inferred conversion is not supported for packed structs with bit
        \\size > 53 (to stay below the JS safe integer limit).
        \\Consider adding an explicit `fn fromJs(Env, Val)` decl instead, or
        \\changing the backing integer type, if feasible.
        \\
        \\(❓) You may need to build with the `-freference-trace`
        \\     flag to find the relevant source location.
    , .{@typeName(PackedStruct)}));

    return struct {
        pub fn fromJs(env: Env, val: Val) !PackedStruct {
            return @bitCast(val.int(Int, env) catch |err| return switch (err) {
                error.IntegerOutOfRange => error.InvalidFlagValue,
                else => err,
            });
        }
    };
}
