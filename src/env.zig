const std = @import("std");

const Array = @import("root.zig").Array;
const ArrayBuffer = @import("root.zig").ArrayBuffer;
const Buffer = @import("root.zig").Buffer;
const Class = @import("root.zig").Class;
const DataView = @import("root.zig").DataView;
const Date = @import("root.zig").Date;
const Fn = @import("root.zig").Fn;
const int_safe_max = @import("root.zig").int_safe_max;
const int_safe_min = @import("root.zig").int_safe_min;
const n = @import("napi.zig");
const NodeVersion = @import("root.zig").NodeVersion;
const Object = @import("root.zig").Object;
const Promise = @import("root.zig").Promise;
const requireNapiVersion = @import("features.zig").requireNapiVersion;
const Symbol = @import("root.zig").Symbol;
const Val = @import("root.zig").Val;

/// Provides an interface to interacting with the the Node-API engine. Enables
/// JS value creation, access, and manipulation.
///
/// Intended to be used mostly in the context of native callbacks on the main
/// thread and should not be cached for reuse in other threads/contexts.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_env
pub const Env = *const NapiEnv;
const NapiEnv = opaque {
    const ext_array = @import("array/Env.zig");
    const ext_array_buffer = @import("array_buffer/Env.zig");
    const ext_async = @import("async/Env.zig");
    const ext_date = @import("date/Env.zig");
    const ext_error = @import("error/Env.zig");
    const ext_function = @import("function/Env.zig");
    const ext_global = @import("global/Env.zig");
    const ext_heap = @import("heap/Env.zig");
    const ext_lifetime = @import("lifetime/Env.zig");
    const ext_number = @import("number/Env.zig");
    const ext_object = @import("object/Env.zig");
    const ext_string = @import("string/Env.zig");

    pub const addCleanup = ext_heap.addCleanup;
    pub const addCleanupAsync = ext_heap.addCleanupAsync;
    pub const addCleanupAsyncRemovable = ext_heap.addCleanupAsyncRemovable;
    pub const adjustOwnedMem = ext_heap.adjustOwnedMem;
    pub const api = ext_object.api;
    pub const array = ext_array.array;
    pub const arrayBuffer = ext_array_buffer.arrayBuffer;
    pub const arrayBufferFrom = ext_array_buffer.arrayBufferFrom;
    pub const arrayBufferOwned = ext_array_buffer.arrayBufferOwned;
    pub const arrayFrom = ext_array.arrayFrom;
    pub const arrayN = ext_array.arrayN;
    pub const asyncTask = ext_async.asyncTask;
    pub const asyncTaskManaged = ext_async.asyncTaskManaged;
    pub const asyncWorker = ext_async.asyncWorker;
    pub const asyncWorkerT = ext_async.asyncWorkerT;
    pub const bigInt = ext_number.bigInt;
    pub const bigIntI64 = ext_number.bigIntI64;
    pub const bigIntU64 = ext_number.bigIntU64;
    pub const boolean = ext_global.boolean;
    pub const buffer = ext_array_buffer.buffer;
    pub const bufferFrom = ext_array_buffer.bufferFrom;
    pub const bufferOwned = ext_array_buffer.bufferOwned;
    pub const class = ext_object.class;
    pub const classT = ext_object.classT;
    pub const dataView = ext_array_buffer.dataView;
    pub const dataViewFrom = ext_array_buffer.dataViewFrom;
    pub const date = ext_date.date;
    pub const enumObject = ext_object.enumObject;
    pub const err = ext_error.err;
    pub const errRange = ext_error.errRange;
    pub const errSyntax = ext_error.errSyntax;
    pub const errType = ext_error.errType;
    pub const external = ext_heap.external;
    pub const float64 = ext_number.float64;
    pub const function = ext_function.function;
    pub const functionNamed = ext_function.functionNamed;
    pub const functionNamedT = ext_function.functionNamedT;
    pub const functionT = ext_function.functionT;
    pub const global = ext_global.global;
    pub const handleScope = ext_lifetime.handleScope;
    pub const handleScopeEscapable = ext_lifetime.handleScopeEscapable;
    pub const instanceData = ext_heap.instanceData;
    pub const instanceDataSet = ext_heap.instanceDataSet;
    pub const int32 = ext_number.int32;
    pub const int54 = ext_number.int54;
    pub const isExceptionPending = ext_error.isExceptionPending;
    pub const lastExceptionGetAndClear = ext_error.lastExceptionGetAndClear;
    pub const lastNapiErr = ext_error.lastNapiErr;
    pub const nullVal = ext_global.nullVal;
    pub const object = ext_object.object;
    pub const objectDefine = ext_object.objectDefine;
    pub const objectFrom = ext_object.objectFrom;
    pub const orNull = ext_global.orNull;
    pub const orUndefined = ext_global.orUndefined;
    pub const promise = ext_async.promise;
    pub const promiseReject = ext_async.promiseReject;
    pub const promiseResolve = ext_async.promiseResolve;
    pub const propKey = ext_object.propKey;
    pub const propKeyLatin1 = ext_object.propKeyLatin1;
    pub const propKeyUtf16 = ext_object.propKeyUtf16;
    pub const string = ext_string.string;
    pub const stringZ = ext_string.stringZ;
    pub const strLatin1 = ext_string.strLatin1;
    pub const strLatin1Owned = ext_string.strLatin1Owned;
    pub const strUtf16 = ext_string.strUtf16;
    pub const strUtf16Owned = ext_string.strUtf16Owned;
    pub const strUtf16Z = ext_string.strUtf16Z;
    pub const symbol = ext_global.symbol;
    pub const symbolFor = ext_global.symbolFor;
    pub const threadsafeFn = ext_async.threadsafeFn;
    pub const throw = ext_error.throw;
    pub const throwErr = ext_error.throwErr;
    pub const throwErrCode = ext_error.throwErrCode;
    pub const throwOrPanic = ext_error.throwOrPanic;
    pub const throwErrRange = ext_error.throwErrRange;
    pub const throwErrSyntax = ext_error.throwErrSyntax;
    pub const throwErrType = ext_error.throwErrType;
    pub const typedArray = ext_array_buffer.typedArray;
    pub const typedArrayFrom = ext_array_buffer.typedArrayFrom;
    pub const uint32 = ext_number.uint32;
    pub const uint53 = ext_number.uint53;
    pub const undefinedVal = ext_global.undefinedVal;

    /// Converts the given value to a corresponding JS value, if the latter
    /// type can be safely inferred.
    ///
    /// Intended for use internally for return type/argument inference, but may
    /// be externally useful in some cases (e.g. writing a custom `toJs()`
    /// conversion for a complex type).
    pub fn infer(self: Env, value: anytype) !Val {

        // Unwrap optionals and error unions to make things a little simpler in
        // the conversion block and avoid a recursive call in a few cases.
        const payload = switch (comptime @typeInfo(@TypeOf(value))) {
            .error_union => try value,
            .optional => value orelse return self.undefinedVal(),
            else => value,
        };

        return switch (comptime @TypeOf(payload)) {
            [:0]const u8,
            [:0]u8,
            []const u8,
            []u8,
            => self.string(payload),

            [*:0]const u8,
            [*:0]u8,
            => self.stringZ(payload),

            Array,
            ArrayBuffer,
            Buffer,
            Class,
            DataView,
            Fn,
            Object,
            Promise,
            Symbol,
            => payload.ptr,

            bool => self.boolean(payload),

            comptime_float => self.float64(payload),

            comptime_int => switch (comptime payload) {
                int_safe_min...int_safe_max => self.int54(payload),
                else => @compileError(
                    \\Inferred type conversion from `comptime_int` values
                    \\outside the range `int_safe_min..int_safe_max` is
                    \\unsupported. Consider converting to BigInt first, or using
                    \\`i54` or greater, for inferred conversion to BigInt.
                    \\
                    \\(❓) You may need to build with the `-freference-trace`
                    \\     flag to find the relevant source location.
                ),
            },

            Date => self.date(payload.timestamp_ms),

            isize => @compileError(
                \\Inferred type conversion from `isize` is unsupported.
                \\Consider using i53 or smaller, for an explicit conversion to a
                \\JS `Number` within the safe integer range, or i54 or greater,
                \\for conversion to BigInt.
                \\
                \\(❓) You may need to build with the `-freference-trace`
                \\     flag to find the relevant source location.
            ),

            type => if (comptime @hasDecl(payload, "toJs"))
                try payload.toJs(self)
            else switch (@typeInfo(payload)) {
                .@"enum" => (try self.enumObject(payload)).ptr,

                .@"struct" => (try self.api(payload, {})).ptr,

                .@"opaque",
                .@"union",
                => @compileError(std.fmt.comptimePrint(
                    \\Inferred type conversion is not supported for {s}
                    \\Consider adding a `fn toJs(Env) !Val` method to the
                    \\type to define a custom conversion function.
                    \\
                    \\(❓) You may need to build with the `-freference-trace`
                    \\     flag to find the relevant source location.
                , .{@typeName(payload)})),

                else => @compileError(std.fmt.comptimePrint(
                    \\Inferred type conversion is not supported for {s}
                    \\Consider converting to `Val` first, or to a type
                    \\for which conversion is supported.
                    \\
                    \\(❓) You may need to build with the `-freference-trace`
                    \\     flag to find the relevant source location.
                , .{@typeName(payload)})),
            },

            usize => @compileError(
                \\Inferred type conversion from `usize` is unsupported.
                \\Consider using u53 or smaller, for an explicit conversion to a
                \\JS `Number` within the safe integer range, or u54 or greater,
                \\for conversion to BigInt.
                \\
                \\(❓) You may need to build with the `-freference-trace`
                \\     flag to find the relevant source location.
            ),

            Val => payload,

            void => self.undefinedVal(),

            else => |T| switch (comptime @typeInfo(T)) {
                .array => (try self.arrayFrom(payload)).ptr,

                .float => |float_info| switch (float_info.bits) {
                    16, 32, 64 => self.float64(payload),
                    else => @compileError(std.fmt.comptimePrint(
                        \\Inferred type conversion from {s} is unsupported.
                        \\Consider converting to f64 or smaller first.
                        \\
                        \\(❓) You may need to build with the `-freference-trace`
                        \\     flag to find the relevant source location.
                    , .{@typeName(T)})),
                },

                .int => |int_info| self.inferInt(int_info, payload),

                .pointer => |ptr_info| switch (ptr_info.size) {
                    .slice => (try self.arrayFrom(payload)).ptr,

                    .one => switch (@typeInfo(ptr_info.child)) {
                        .array => |array_info| self.inferArray(
                            array_info,
                            payload,
                        ),

                        .@"struct" => |struct_info| self.inferStruct(
                            ptr_info.child,
                            struct_info,
                            payload,
                        ),

                        else => @compileError(std.fmt.comptimePrint(
                            \\Inferred type conversion is not supported for {s}
                            \\Consider converting to `Val` first, or to a type
                            \\for which conversion is supported.
                            \\
                            \\(❓) You may need to build with the `-freference-trace`
                            \\     flag to find the relevant source location.
                        , .{@typeName(T)})),
                    },

                    else => @compileError(std.fmt.comptimePrint(
                        \\Inferred type conversion is not supported for {s}
                        \\Consider converting to `Val` first, or to a type
                        \\for which conversion is supported.
                        \\
                        \\(❓) You may need to build with the `-freference-trace`
                        \\     flag to find the relevant source location.
                    , .{@typeName(T)})),
                },

                .@"enum" => |enum_info| if (@hasDecl(T, "toJs"))
                    payload.toJs(self)
                else
                    self.inferInt(
                        @typeInfo(enum_info.tag_type).int,
                        @as(enum_info.tag_type, @intFromEnum(payload)),
                    ),

                .@"fn" => (try self.function(payload)).ptr,

                .@"struct" => |struct_info| self.inferStruct(
                    T,
                    struct_info,
                    payload,
                ),

                .@"opaque", .@"union" => if (@hasDecl(T, "toJs"))
                    payload.toJs(self)
                else
                    @compileError(std.fmt.comptimePrint(
                        \\Inferred type conversion is not supported for {[0]s}
                        \\Consider adding a `pub fn toJs({[0]s}, Env) !Val`,
                        \\method, or converting to `Val` first.
                        \\
                        \\(❓) You may need to build with the `-freference-trace`
                        \\     flag to find the relevant source location.
                    , .{@typeName(T)})),

                else => @compileError(std.fmt.comptimePrint(
                    \\Inferred type conversion is not supported for {s}
                    \\Consider converting to `Val` first, or to a type
                    \\for which conversion is supported.
                    \\
                    \\(❓) You may need to build with the `-freference-trace`
                    \\     flag to find the relevant source location.
                , .{@typeName(T)})),
            },
        };
    }

    /// https://nodejs.org/docs/latest/api/n-api.html#node_api_get_module_file_name
    pub fn moduleFileName(self: Env) ![*:0]const u8 {
        requireNapiVersion(.v9);

        var filename: ?[*:0]const u8 = null;
        try n.node_api_get_module_file_name(self, &filename).check();

        return filename.?;
    }

    /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_node_version
    pub fn nodeVersion(self: Env) !*const NodeVersion {
        var version: ?*const NodeVersion = null;
        try n.napi_get_node_version(self, &version).check();

        return version.?;
    }

    /// Executes the given JS code and returns its result, with the following
    /// caveats:
    ///
    /// - Unlike `eval()` in JS, this function does not allow the script to
    ///   access the current lexical scope, and therefore also does not allow to
    ///   access the module scope, meaning that pseudo-globals such as `require`
    ///   will not be available.
    ///
    /// - The script can access the global scope.
    ///
    /// - `function` and `var` declarations in the script will be added to the
    ///   global object.
    ///
    /// - Variable declarations made using `let` and `const` will be visible
    ///   globally, but will not be added to the global object.
    ///
    /// - The value of this is global within the script.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_run_script
    pub fn run(self: Env, script: []const u8) !Val {
        var ptr: ?Val = null;
        try n.napi_run_script(self, try self.string(script), &ptr).check();

        return ptr.?;
    }

    inline fn inferArray(
        self: Env,
        comptime info: std.builtin.Type.Array,
        payload: anytype,
    ) !Val {
        return switch (info.child) {
            u8 => switch (@typeInfo(@TypeOf(payload))) {
                .pointer => self.string(payload),
                else => self.string(&payload),
            },
            else => (try self.arrayFrom(payload)).ptr,
        };
    }

    inline fn inferInt(
        self: Env,
        comptime info: std.builtin.Type.Int,
        payload: anytype,
    ) !Val {
        return switch (info.signedness) {
            .signed => switch (comptime info.bits) {
                0...32 => self.int32(payload),
                // Could be `33...54` in practice, but that would accept a value
                // of `-2^53, which would only error at run time. Opting for
                // comptime safety instead.
                33...53 => self.int54(payload),
                54...64 => self.bigIntI64(payload),
                else => self.bigInt(payload),
            },

            .unsigned => switch (comptime info.bits) {
                0...32 => self.uint32(payload),
                33...53 => self.uint53(payload),
                54...64 => self.bigIntU64(payload),
                else => self.bigInt(payload),
            },
        };
    }

    inline fn inferStruct(
        self: Env,
        comptime T: type,
        comptime info: std.builtin.Type.Struct,
        payload: anytype,
    ) !Val {
        if (comptime @hasDecl(T, "toJs")) return payload.toJs(self);
        if (comptime info.is_tuple) return (try self.arrayFrom(payload)).ptr;

        return switch (info.layout) {
            .@"packed" => self.inferInt(
                @typeInfo(info.backing_integer.?).int,
                @as(info.backing_integer.?, @bitCast(payload)),
            ),

            else => (try self.objectFrom(payload)).ptr,
        };
    }
};
