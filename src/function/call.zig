const std = @import("std");

const Class = @import("../root.zig").Class;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Object = @import("../root.zig").Object;
const Val = @import("../root.zig").Val;

/// Represents a call from the JS main thread into a Zig function.
/// Contains a handle to the JS execution environment, along with the arguments
/// and JS `this` object context of the call, where applicable.
///
/// Provided to exported functions that receive a `Call` as the first argument.
/// Can be omitted if not needed.
///
/// For the data-bound variant, see `CallT`.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn exportedFn(call: t.Call) !t.TypedArray(.u8) {
///     // Function parameters from JS:
///     const arg_one, const arg_two = try call.args(2);
///
///     // The `this` context object:
///     const this = try call.this();
///
///     // The `env` field can be used to interact with the JS runtime and/or
///     // create new JS values:
///     return call.env.typedArrayFrom(&[_]u8{ 0xca, 0xfe });
/// }
/// ```
pub const Call = struct {
    env: Env,
    info: n.CallInfo,

    const Impl = CallImpl(@This());
    pub const argCount = Impl.argCount;
    pub const args = Impl.args;
    pub const argsAs = Impl.argsAs;
    pub const argsBuf = Impl.argsBuf;
    pub const constructor = Impl.constructor;
    pub const this = Impl.this;
    pub const thisOrNull = Impl.thisOrNull;
    pub const thisUnwrap = Impl.thisUnwrap;

    pub fn fromJs(_: Env, _: Val) !Call {
        @compileError(
            \\Attempted to convert JS value arg to `tokota.Call`.
            \\This could mean:
            \\  - You're attempting to receive `tokota.Call` as the first
            \\    argument of a callback which has native data bound (in which
            \\    case, try using `tokota.CallT(T)` instead)
            \\  - `tokota.Call` is not the first argument of the callback.
            \\
            \\(❓) You may need to build with the `-freference-trace` flag to
            \\     find the relevant source location.
        );
    }
};

/// Similar to `Call`, this represents a call from the JS main thread into a Zig
/// function. Contains a handle to the JS execution environment, along with the
/// arguments and JS `this` object context of the call, where applicable.
///
/// Provided to exported functions that receive a `CallT` as the first
/// argument and were bound, at the time of creation, to native data, which can
/// be extracted with `CallT.data()`. Can be omitted if not needed.
///
/// Options for binding native data to JS functions:
/// - `Api` - Supports returning an object interface with all
///   methods bound to native data.
/// - `Closure` - Supports returning a single native function
///   for conversion to a native-data-bound JS function.
/// - `Env.functionT()` - Used under the hood by `Api` and `Closure` and may be
///   simpler if memory cleanup isn't needed, or if more flexibility is desired.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// const MethodData = struct { foo: u32 };
/// const method_data = MethodData{ .foo = 30 };
///
/// pub fn exportedFn(call: t.Call) !t.Fn {
///     // Return a JS function with native data attached:
///     return call.env.functionT(callbackWithData, &method_data);
/// }
///
/// fn callbackWithData(call: t.CallT(MethodData)) !u32 {
///     // Function parameters from JS:
///     const arg_one, const arg_two = try call.args(2);
///
///     // The `this` context object:
///     const this = try call.this();
///
///     // Retrieve previously attached native data from above:
///     const data = try call.data() orelse return error.MissingData;
///
///     return data.foo;
/// }
/// ```
pub fn CallT(comptime T: type) type {
    return struct {
        const Self = @This();

        env: Env,
        info: n.CallInfo,

        const Impl = CallImpl(@This());
        pub const argCount = Impl.argCount;
        pub const args = Impl.args;
        pub const argsAs = Impl.argsAs;
        pub const argsBuf = Impl.argsBuf;
        pub const constructor = Impl.constructor;
        pub const this = Impl.this;
        pub const thisOrNull = Impl.thisOrNull;
        pub const thisUnwrap = Impl.thisUnwrap;

        /// The native data, if any, that was attached to the function at the
        /// time of creation.
        ///
        /// See `CallT` for example usage.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
        pub fn data(self: Self) !?T {
            var ptr: ?T = null;
            try n.napi_get_cb_info(
                self.env,
                self.info,
                null,
                null,
                null,
                @ptrCast(&ptr),
            ).check();

            return ptr;
        }

        pub fn fromJs(_: Env, _: Val) !Self {
            @compileError(
                \\Attempted to convert JS value arg to `tokota.CallT(T)`.
                \\This could mean:
                \\  - The type `T` in the `tokota.CallT(T)` arg doesn't match
                \\    the type of data bound to the callback.
                \\  - You're attempting to receive `tokota.CallT(T)` as the
                \\    as the first argument of a callback with no native data
                \\    bound (in which case, try using `tokota.Call` instead).
                \\      - Make sure the callback function is not a top-level
                \\        pub export, as CallT is not supported there.
                \\  - `tokota.CallT(T)` is not the first argument of the callback.
                \\
                \\(❓) You may need to build with the `-freference-trace` flag
                \\     to find the relevant source location.
            );
        }
    };
}

fn CallImpl(comptime Self: type) type {
    if (!@hasField(Self, "env") or @FieldType(Self, "env") != Env) {
        @compileError("CallImpl target must contain an `env: Env` field");
    }

    if (!@hasField(Self, "info") or @FieldType(Self, "info") != n.CallInfo) {
        @compileError(
            \\CallImpl target must contain an `info: n.CallInfo` field
        );
    }

    return struct {
        /// The number of arguments specified by the JS caller.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
        pub fn argCount(self: Self) !usize {
            var count: usize = 0;
            try n.napi_get_cb_info(
                self.env,
                self.info,
                &count,
                null,
                null,
                null,
            ).check();

            return count;
        }

        /// Returns the first `count` arguments from the JS call.
        ///
        /// If the function was called with fewer than `count` arguments, the
        /// `Val`s corresponding to the missing arguments will be of JS type
        /// `undefined`.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
        pub inline fn args(self: Self, comptime count: usize) ![count]Val {
            var len: usize = count;
            var arr: [count]Val = undefined;
            try n.napi_get_cb_info(self.env, self.info, &len, &arr, null, null)
                .check();

            return arr;
        }

        /// Returns the first `types.len` arguments from the JS call, converted
        /// to the given `types` in order.
        ///
        /// Any argument that is incompatible with the corresponding type in
        /// `types` will cause a JS `TypeError` exception to be thrown and
        /// `error.PendingException` to be returned.
        ///
        /// Any argument corresponding to an optional type in `types` will be
        /// set to `null` if the JS argument is missing or of type
        /// `null`/`undefined`.
        ///
        /// If the function was called with fewer than `types.len` arguments,
        /// the missing arguments will be of JS type `undefined` and will result
        /// in a JS error if the corresponding Zig types are non-optional.
        ///
        /// ## Example
        ///
        /// ```zig
        /// const t = @import("tokota");
        ///
        /// comptime {
        ///     t.exportModule(@This());
        /// }
        ///
        /// const Uint8Array = t.TypedArray(.u8);
        ///
        /// pub fn decrypt(call: t.Call) !?Uint8Array {
        ///     const buf, const callback = call.argsAs(.{ Uint8Array, ?t.Fn });
        ///
        ///     if (callback) |cb| {
        ///         decryptAsync(buf, cb);
        ///         return null;
        ///     }
        ///
        ///     return decryptSync(buf);
        /// }
        /// ```
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
        pub inline fn argsAs(
            self: Self,
            comptime types: anytype,
        ) !ArgsTuple(types) {
            const Args = ArgsTuple(types);
            const fields = comptime @typeInfo(Args).@"struct".fields;
            const max_count = comptime fields.len;

            var buf_args: [max_count]Val = undefined;
            var count: usize = max_count;
            try n.napi_get_cb_info(
                self.env,
                self.info,
                &count,
                &buf_args,
                null,
                null,
            ).check();

            var buf_err: [128]u8 = undefined;
            var result: Args = undefined;

            inline for (buf_args, types, &result, 0..) |arg, T, *field, idx| {
                field.* = arg.to(self.env, T) catch |e| {
                    return self.env.throwErrType(.{
                        .code = @errorName(e),
                        .msg = try std.fmt.bufPrintZ(
                            &buf_err,
                            "[{t}] Argument error at index {d}",
                            .{ e, idx },
                        ),
                    });
                };
            }

            return result;
        }

        /// Returns a slice of `buf` with, at most, the first `buf.len`
        /// arguments from the JS call.
        ///
        /// If the function was called with fewer than `buf.len` arguments, the
        /// length of the returned slice will reflect the actual number of
        /// arguments.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
        pub fn argsBuf(self: Self, buf: []Val) ![]Val {
            var len: usize = buf.len;
            try n.napi_get_cb_info(
                self.env,
                self.info,
                &len,
                buf.ptr,
                null,
                null,
            ).check();

            return buf[0..len];
        }

        /// The JS `Class` constructor for the current `new` call. Only
        /// available from within a `Class` constructor callback - `null` for
        /// all other calls.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_new_target
        pub fn constructor(self: Self) !?Class {
            var ptr: ?Val = null;
            try n.napi_get_new_target(self.env, self.info, &ptr).check();

            if (ptr == null) {
                return null;
            }

            return .{ .env = self.env, .ptr = ptr.? };
        }

        /// The JS [this](https://mdn.io/Operators/this) object to which the
        /// called function is bound.
        ///
        /// Returns `error.InvalidThis`, if the `this` object is not bound.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
        pub fn this(self: Self) !Object {
            return try self.thisOrNull() orelse error.InvalidThis;
        }

        /// The JS [this](https://mdn.io/Operators/this) object, if any, to
        /// which the called function is bound.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_get_cb_info
        pub fn thisOrNull(self: Self) !?Object {
            var ptr: ?Val = null;
            try n.napi_get_cb_info(self.env, self.info, null, null, &ptr, null)
                .check();

            if (try ptr.?.isNullOrUndefined(self.env)) return null;

            return ptr.?.object(self.env);
        }

        /// Unwraps an instance of the given native type from the `this` context
        /// object for this call.
        ///
        /// > #### ⚠ NOTE
        /// > The instance must have been previously wrapped in the JS
        /// object `Object.wrap()` for this to work.
        ///
        /// Throws a JS error if there is no `this` context for the call, or if
        /// the type tag on the `this` object doesn't match the type tag on `T`.
        pub fn thisUnwrap(self: Self, comptime T: type) !?T {
            const this_obj = try self.thisOrNull() orelse return null;
            return this_obj.unwrap(T);
        }

        fn ArgsTuple(comptime types: anytype) type {
            const count = switch (@typeInfo((@TypeOf(types)))) {
                .@"struct" => |info| blk: {
                    if (!info.is_tuple) @compileError(
                        \\Expected tuple or array of type values.
                    );

                    break :blk info.fields.len;
                },
                .array => |info| info.len,
                else => @compileError(
                    \\Expected tuple or array of type values.
                ),
            };

            var fields: [count]std.builtin.Type.StructField = undefined;
            for (types, 0..) |T, i| {
                fields[i] = std.builtin.Type.StructField{
                    .alignment = @alignOf(T),
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .name = std.fmt.comptimePrint("{d}", .{i}),
                    .type = T,
                };
            }

            return @Type(.{
                .@"struct" = .{
                    .decls = &.{},
                    .fields = &fields,
                    .is_tuple = true,
                    .layout = .auto,
                },
            });
        }
    };
}
