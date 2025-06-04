const std = @import("std");

const base = @import("base");

const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const n = @import("../root.zig").napi;
const napiCb = @import("../root.zig").napiCb;
const Promise = @import("../root.zig").Promise;
const Val = @import("../root.zig").Val;

/// Descriptor for a JS Object property. Used in defining JS `Class`/`Object`
/// values via `Env.objectDefine()`, `Object.define()`, and
/// `Env.class()`/`Env.classT()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_property_descriptor
pub const Property = extern struct {
    /// UTF-8-encoded name. Required if `name_val` is `null`.
    name: ?[*:0]const u8 = null,

    /// JS `String` or `Symbol` property name. Required if `name` is `null`.
    name_val: ?Val = null,

    /// Zig callback for a method property.
    method_cb: ?n.Callback = null,

    /// Zig callback for an accessor value property getter.
    getter_cb: ?n.Callback = null,

    /// Zig callback for an accessor value property setter.
    setter_cb: ?n.Callback = null,

    /// Non-function value property.
    val: ?Val = null,

    /// Property [attributes](https://tc39.es/ecma262/#table-2).
    attributes: Attributes = .empty,

    /// Context data to attach to method properties.
    /// Available in callbacks via `Call.data()`.
    data: ?AnyPtrConst = null,

    /// https://nodejs.org/docs/latest/api/n-api.html#napi_property_attributes
    pub const Attributes = packed struct(u32) {
        writable: bool = false,
        enumerable: bool = false,
        configurable: bool = false,
        _3: u7 = 0,
        static: bool = false,
        _: u21 = 0,

        pub const empty = Attributes{};
        pub const method = Attributes{ .enumerable = true };
        pub const value = Attributes{ .enumerable = true };

        const Impl = base.BitFlagsImpl(@This());
        pub const format = Impl.format;
        pub const hasAll = Impl.hasAll;
        pub const hasAny = Impl.hasAny;
        pub const intersection = Impl.intersection;
        pub const unionWith = Impl.unionWith;
        pub const val = Impl.val;
    };

    pub const MethodOptions = struct {
        /// Context data to attach to method properties.
        /// Available in callbacks via `Call.data()`.
        data: ?AnyPtrConst = null,

        /// Only applicable to `Class` definitions - makes the method available
        /// as a static method.
        static: bool = false,
    };

    /// Creates a JS object method property, with the given Zig function as the
    /// receiving callback.
    ///
    /// ## Example
    /// ```zig
    /// //! addon.zig
    ///
    /// const t = @import("tokota");
    ///
    /// comptime { t.exportModule(@This()); }
    ///
    /// pub fn foo(call: t.Call) !t.Object {
    ///     return call.env.objectDefine(&.{
    ///         .method("bar", bar, .{}),
    ///     });
    /// }
    ///
    /// fn bar() []const u8 {
    ///     return "baz";
    /// }
    /// ```
    ///
    /// ```js
    /// // main.js
    ///
    /// const assert = require("node:assert");
    /// const addon = require("./addon.node");
    ///
    /// const foo = addon.foo();
    /// assert.equal(foo.bar(), "baz");
    /// ```
    pub fn method(
        /// A JS `Val`, `[:0]const u8`, or `[*:0]const u8`
        /// (or anything that can be coerced to those types).
        name: anytype,
        /// Any Zig function with a signature compatible with `napiCb()`.
        comptime fn_zig: anytype,
        /// Additional options.
        opts: MethodOptions,
    ) Property {
        const name_str, const name_val = propName(name);

        return .{
            .attributes = Attributes.method.unionWith(.{
                .static = opts.static,
            }),
            .method_cb = napiCb(fn_zig, .{}),
            .name = name_str,
            .name_val = name_val,
        };
    }

    /// Creates a JS object method property, with the given Zig function as the
    /// receiving callback. Additionally, `data` is bound to the method and can
    /// later be extracted from incoming calls via `CallT.data()`.
    ///
    /// ## Example
    /// ```zig
    /// //! addon.zig
    ///
    /// const t = @import("tokota");
    ///
    /// comptime { t.exportModule(@This()); }
    ///
    /// const MethodData = struct { msg: []const u8 };
    /// const method_data = MethodData{ .msg = "baz" };
    ///
    /// pub fn foo(call: t.Call) !t.Object {
    ///     return call.env.objectDefine(&.{
    ///         .methodT("bar", bar, &method_data, .{}),
    ///     });
    /// }
    ///
    /// fn bar(call: t.CallT(*const MethodData)) ![]const u8 {
    ///     const data = try call.data() orelse return error.MissingData;
    ///     return data.msg;
    /// }
    /// ```
    ///
    /// ```js
    /// // main.js
    ///
    /// const assert = require("node:assert");
    /// const addon = require("./addon.node");
    ///
    /// const foo = addon.foo();
    /// assert.equal(foo.bar(), "baz");
    /// ```
    pub fn methodT(
        /// A JS `Val`, `[:0]const u8`, or `[*:0]const u8`
        /// (or anything that can be coerced to those types).
        name: anytype,
        /// Any Zig function with a signature compatible with `napiCb()`.
        comptime fn_zig: anytype,
        /// Pointer to the data to bind to the method.
        data: anytype,
        /// Additional options.
        opts: MethodOptions,
    ) Property {
        const name_str, const name_val = propName(name);

        return .{
            .attributes = Attributes.method.unionWith(.{
                .static = opts.static,
            }),
            .data = data,
            .method_cb = napiCb(fn_zig, .{ .DataType = @TypeOf(data) }),
            .name = name_str,
            .name_val = name_val,
        };
    }

    pub const ValueOptions = struct {
        /// Only applicable to `Class` definitions - makes the value available
        /// as a static property.
        static: bool = false,
    };

    /// Creates a JS object value property, which will available as a field on
    /// on the object, with the given name.
    ///
    /// `name` can be a Zig string type (anything that coerces to a
    /// `[]const u8`, or a `[*:0]const u8`), or an existing JS `Val`.
    ///
    /// ## Example
    /// ```zig
    /// //! addon.zig
    ///
    /// const t = @import("tokota");
    ///
    /// comptime { t.exportModule(@This()); }
    ///
    /// pub fn foo(call: t.Call) !t.Object {
    ///     return call.env.objectDefine(&.{
    ///         .value("bar", try call.env.string("one"), .{}),
    ///         .value("baz", try call.env.arrayFrom(.{ true, 3 }), .{}),
    ///     });
    /// }
    /// ```
    ///
    /// ```js
    /// // main.js
    ///
    /// const assert = require("node:assert");
    /// const addon = require("./addon.node");
    ///
    /// assert.deepEqual(addon.foo(), {
    ///   bar: "one",
    ///   baz: [true, 3],
    /// });
    /// ```
    pub fn value(name: anytype, val: anytype, opts: ValueOptions) Property {
        const name_str, const name_val = propName(name);

        return .{
            .attributes = Attributes.value.unionWith(.{
                .static = opts.static,
            }),
            .name = name_str,
            .name_val = name_val,
            .val = switch (@TypeOf(val)) {
                Val => val,

                else => |T| blk: {
                    if (@typeInfo(T) == .@"struct" and @hasField(T, "ptr")) {
                        switch (@TypeOf(val.ptr)) {
                            Val => break :blk val.ptr,
                            else => @compileError(std.fmt.comptimePrint(
                                \\Cannot extract JS value from {s}.
                                \\Try converting to a `tokota.Val` first.
                                \\
                            , .{@typeName(T)})),
                        }
                    } else {
                        @compileError(std.fmt.comptimePrint(
                            \\Cannot extract JS value from {s}.
                            \\Try converting to a `tokota.Val` first.
                            \\
                        , .{@typeName(T)}));
                    }
                },
            },
        };
    }
};

fn propName(name: anytype) struct { ?[*:0]const u8, ?Val } {
    return switch (@TypeOf(name)) {
        Val => .{ null, name },

        [*:0]u8,
        [*:0]const u8,
        => .{ name, null },

        // Let the compiler catch anything that can't be coerced to a C string.
        else => .{
            @as([:0]const u8, name).ptr,
            null,
        },
    };
}
