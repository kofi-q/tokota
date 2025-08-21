//! Represents a JS [Object](https://mdn.io/Obejct) value. Provides an API for
//! getting/setting properties and managing related lifetimes.
//!
//! Can be:
//! - Newly allocated via `Env.object()`, `Env.objectDefine()`, or
//!   `Env.objectFrom()`.
//! - Cast from an existing JS value via `Val.object()`.
//! - Coerced from an existing JS value via `Val.objectCoerce()`.
//! - Received as an argument in a Node-API callback.
//!
//! ## Example
//! ```zig
//! //! addon.zig
//!
//! const std = @import("std");
//! const t = @import("tokota");
//!
//! comptime {
//!     t.exportModule(@This());
//! }
//!
//! pub fn create(call: t.Call) !t.Object {
//!     return try call.env.objectDefine(&.{
//!         .value("x", try call.env.float64(19.86), .{}),
//!         .value("y", try call.env.float64(7.08), .{}),
//!     });
//! }
//!
//! const Coords = struct { x: f64, y: f64 };
//!
//! pub fn convert() Coords {
//!     // `Env.objectFrom()` is invoked under
//!     // the hood for struct returns:
//!     return Coords{ .x = 3.142, .y = 1.618 };
//! }
//!
//! pub fn modify(coords: t.Object) !t.Object {
//!     const x = try coords.getT("x", f64);
//!     const y = try coords.getT("y", f64);
//!
//!     try coords.set("x", x / 2);
//!     try coords.set("y", y / 2);
//!
//!     return coords;
//! }
//! ```
//!
//! ```js
//! // main.js
//!
//! const assert = require("node:assert");
//! const addon = require("./addon.node");
//!
//! assert.deepEqual(addon.create(), { x: 19.86, y: 7.08 });
//! assert.deepEqual(addon.convert(), { x: 3.142, y: 1.618 });
//! assert.deepEqual(addon.modify({ x: 10.6, y: 5 }), { x: 5.3, y: 2.5 });
//! ```

const std = @import("std");
const comptimePrint = std.fmt.comptimePrint;

const base = @import("base");

const AnyPtr = @import("../root.zig").AnyPtr;
const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Array = @import("../root.zig").Array;
const Env = @import("../root.zig").Env;
const Err = @import("../root.zig").Err;
const Finalizer = @import("../root.zig").Finalizer;
const log = @import("../root.zig").log;
const n = @import("../napi.zig");
const Property = @import("property.zig").Property;
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

const Object = @This();

ptr: Val,
env: Env,

/// Holds a unique, 128-bit integer value for tagging JS objects in order to
/// enable safer type checking later on. This is most useful in conjunction with
/// `Object.wrap()`/`Object.unwrap()` and `Env.external()`/`Val.external()`, to
/// ensure that native pointers attached to JS values can be safely cast to
/// specific Zig types.
///
/// The following command may be useful for generating unique type tags:
/// ```sh
/// uuidgen | sed -r -e 's/-//g' -e 's/(.{16})(.*)/.{ .lower = 0x\L\1, .upper = 0x\L\2, }/'
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_type_tag
pub const Tag = packed struct(u128) {
    lower: u64,
    upper: u64,

    /// Retrieve a required comptime type tag from the given Zig type. A missing
    /// or malformed tag field will result in a compile error.
    pub fn require(comptime T: type) *const Tag {
        const PtrChild = switch (@typeInfo(T)) {
            .pointer => |ptr_info| ptr_info.child,
            else => @compileError(
                "Pointer type required for object wrap/unwrap.",
            ),
        };

        return comptime blk: for (@typeInfo(PtrChild).@"struct".fields) |f| {
            if (!std.mem.eql(u8, f.name, "js_tag")) continue;

            if (!f.is_comptime or f.type != Tag) @compileError(comptimePrint(
                \\Invalid type: {s}
                \\`Object.[wrap|unwrap]()` and `[Env|Val].external() methods
                \\require a struct type with a `comptime js_tag: Object.Tag` field.
            , .{@typeName(T)}));

            break :blk @ptrCast(@alignCast(f.default_value_ptr.?));
        } else @compileError(comptimePrint(
            \\Invalid type: {s}
            \\`Object.[wrap|unwrap]()` and `[Env|Val].external() methods
            \\require a struct type with a `comptime js_tag: Object.Tag` field.
        , .{@typeName(T)}));
    }
};

pub const KeyCollectionMode = enum(c_int) {
    include_prototypes = 0,
    own_only = 1,
};

pub const KeyFilter = packed struct(u32) {
    writable: bool = false,
    enumerable: bool = false,
    configurable: bool = false,
    skip_strings: bool = false,
    skip_symbols: bool = false,
    _: u27 = 0,

    pub const no_filter = KeyFilter{};

    const Impl = base.BitFlagsImpl(@This());
    pub const format = Impl.format;
    pub const hasAll = Impl.hasAll;
    pub const hasAny = Impl.hasAny;
    pub const intersection = Impl.intersection;
    pub const unionWith = Impl.unionWith;
    pub const val = Impl.val;
};

pub const KeyConversion = enum(c_uint) {
    keep_numbers = 0,
    numbers_to_strings = 1,
};

/// Registers a function to be called when this object gets garbage-collected.
/// Enables cleanup of native values whose lifetime should be tied to the JS
/// object.
///
/// This API can be called multiple times on a single JS object.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_add_finalizer
pub fn addFinalizer(self: Object, finalizer: Finalizer) !Ref(Object) {
    var ref_ptr: ?Ref(Object) = null;
    try n.napi_add_finalizer(
        self.env,
        self.ptr,
        finalizer.data,
        finalizer.cb.?,
        finalizer.hint,
        &ref_ptr,
    ).check();

    return ref_ptr.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_define_properties
pub fn define(self: Object, props: []const Property) !void {
    try n.napi_define_properties(self.env, self.ptr, props.len, props.ptr)
        .check();
}

pub const InterfaceOpts = struct {
    /// Context data to attach to method properties.
    /// Available in callbacks via `CallT.data()`.
    method_data: ?AnyPtrConst = null,
};

/// Defines the `Object` as an "API", with method and value properties
/// corresponding to public decls in the given `Struct` type. If non-void,
/// `method_data` can be bound to each exported method and later retrieved from
/// incoming JS calls via `CallT.data()`.
///
/// This is used internally by the `Api` helper type, which may be more
/// convenient, depending on the use case, especially when the method data needs
/// to be cleaned up when the `Object` is garbage-collected.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const std = @import("std");
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// var client: Client = undefined;
///
/// pub fn newClient(call: t.Call) !t.Object {
///     const api = try call.env.object();
///
///     client = .{ .id = 1996 };
///     try api.defineApi(Client, &client);
///
///     return call.env.api(Client, &client);
/// }
///
/// const Client = struct {
///     id: u32,
///
///     fn internal() !void {
///         return error.ShouldNotBeVisible;
///     }
///
///     pub fn getId(call: t.CallT(*Client)) !u32 {
///         const self = try call.data() orelse return error.MissingMethodData;
///         return self.id;
///     }
/// };
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const addon = require("./addon.node");
///
/// const client = addon.newClient();
/// assert.equal(client.getId(), 1996);
///
/// assert.equal(client.internal, undefined);
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_define_properties
pub fn defineApi(
    self: Object,
    comptime Struct: type,
    method_data: anytype,
) !void {
    const info = switch (@typeInfo(Struct)) {
        .@"struct" => |T| T,
        else => |Invalid| @compileError(comptimePrint(
            "Expected struct type, got {}\n",
            .{Invalid},
        )),
    };

    const prop_count_max = info.decls.len;
    var props: [prop_count_max]Property = undefined;

    comptime var count = 0;
    inline for (comptime info.decls) |decl| {
        comptime if (decl.name[0] == '_') continue;
        comptime if (ignored_decls.has(decl.name)) continue;

        const field = @field(Struct, decl.name);

        props[count] = switch (@typeInfo(@TypeOf(field))) {
            .@"fn" => switch (@typeInfo(@TypeOf(method_data))) {
                .void => .method(decl.name, &field, .{}),
                else => .methodT(decl.name, &field, method_data, .{}),
            },
            else => .value(decl.name, try self.env.infer(field), .{}),
        };

        count += 1;
    }

    try self.define(props[0..count]);
}

/// [TODO] Make this configurable/extensible.
const ignored_decls = std.StaticStringMap(void).initComptime(.{
    .{"fromJs"},
    .{"panic"},
    .{"toJs"},
    .{"std_options"},
    .{"tokota_options"},
});

/// Deletes a property from the object, identified by either a native string key
/// or a JS value key.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_delete_property
pub fn delete(self: Object, key: anytype) !bool {
    var res = false;

    switch (@TypeOf(key)) {
        Val => try n.napi_delete_property(
            self.env,
            self.ptr,
            key,
            &res,
        ).check(),

        else => try n.napi_delete_property(
            self.env,
            self.ptr,
            try self.env.string(key),
            &res,
        ).check(),
    }

    return res;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_object_freeze
pub fn freeze(self: Object) !void {
    try n.napi_object_freeze(self.env, self.ptr).check();
}

/// Defines the JS object's properties with values inferred from fields in the
/// given Zig struct instance.
pub fn from(self: Object, obj_struct: anytype) !void {
    const info = switch (@typeInfo(@TypeOf(obj_struct))) {
        .@"struct" => |struct_info| struct_info,

        .pointer => |ptr_info| switch (@typeInfo(ptr_info.child)) {
            .@"struct" => |struct_info| struct_info,
            else => @compileError("Expected struct or struct pointer."),
        },

        else => @compileError("Expected struct or struct pointer."),
    };

    const max_props = info.fields.len;
    var props: [max_props]Property = undefined;

    comptime var prop_count: usize = 0;
    inline for (info.fields) |field_info| {
        // Assume '_'-prefixed fields shouldn't be exported, but need to be
        // public for internal use.
        comptime if (field_info.name[0] == '_') continue;
        comptime if (std.mem.eql(u8, field_info.name, "js_tag")) continue;

        props[prop_count] = switch (@typeInfo(field_info.type)) {
            .@"fn" => .method(
                field_info.name,
                @field(obj_struct, field_info.name),
                .{},
            ),
            else => .value(
                field_info.name,
                try self.env.infer(@field(obj_struct, field_info.name)),
                .{},
            ),
        };

        prop_count += 1;
    }

    try self.define(&props[0..prop_count].*);
}

/// Gets a property value on the object, identified by either a native string
/// key [1], or a JS value key [2].
///
/// - [1] https://nodejs.org/docs/latest/api/n-api.html#napi_get_named_property
/// - [2] https://nodejs.org/docs/latest/api/n-api.html#napi_get_property
pub fn get(self: Object, key: anytype) !Val {
    var val: ?Val = null;

    switch (@TypeOf(key)) {
        Val => try n.napi_get_property(self.env, self.ptr, key, &val).check(),

        else => try n.napi_get_named_property(
            self.env,
            self.ptr,
            @as([:0]const u8, key).ptr,
            &val,
        ).check(),
    }

    return val.?;
}

/// Gets a property value on the object, identified by either a native string
/// key [1], or a JS value key [2]. The resulting value is converted to the
/// given type, if possible, otherwise an error is returned.
///
/// - [1] https://nodejs.org/docs/latest/api/n-api.html#napi_get_named_property
/// - [2] https://nodejs.org/docs/latest/api/n-api.html#napi_get_property
pub inline fn getT(self: Object, key: anytype, comptime T: type) !T {
    return (try self.get(key)).to(self.env, T);
}

/// Checks for the existence of a property on the object, identified by either a
/// native string key [1], or a JS value key [2].
///
/// - [1] https://nodejs.org/docs/latest/api/n-api.html#napi_has_named_property
/// - [2] https://nodejs.org/docs/latest/api/n-api.html#napi_has_property
pub fn has(self: Object, key: anytype) !bool {
    var result: bool = undefined;

    switch (@TypeOf(key)) {
        Val => try n.napi_has_property(
            self.env,
            self.ptr,
            key,
            &result,
        ).check(),

        else => try n.napi_has_named_property(
            self.env,
            self.ptr,
            @as([:0]const u8, key).ptr,
            &result,
        ).check(),
    }

    return result;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_has_own_property
pub fn hasOwn(self: Object, key: anytype) !bool {
    var result: bool = undefined;

    switch (@TypeOf(key)) {
        Val => try n.napi_has_own_property(
            self.env,
            self.ptr,
            key,
            &result,
        ).check(),

        else => try n.napi_has_own_property(
            self.env,
            self.ptr,
            try self.env.string(key),
            &result,
        ).check(),
    }

    return result;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_instanceof
pub fn instanceOf(self: Object, constructor: Val) !bool {
    return self.ptr.instanceOf(self.env, constructor);
}

/// All enumerable keys of the object, as a JS `Array` value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_property_names
pub fn keys(self: Object) !Array {
    var ptr: ?Val = null;
    try n.napi_get_property_names(self.env, self.ptr, &ptr).check();

    return .{ .env = self.env, .ptr = ptr.? };
}

/// All keys of the object, with optional filters, as a JS `Array` value.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_all_property_names
pub fn keysExtended(
    self: Object,
    mode: KeyCollectionMode,
    filter: KeyFilter,
    conversion: KeyConversion,
) !Array {
    var res: ?Val = null;
    try n.napi_get_all_property_names(
        self.env,
        self.ptr,
        mode,
        filter,
        conversion,
        &res,
    ).check();

    return .{ .env = self.env, .ptr = res.? };
}

/// Creates a `Ref` from which the `Object` can later be extracted, outside of
/// the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: Object, initial_ref_count: u32) !Ref(Object) {
    var ptr: ?Ref(Object) = null;
    try n.napi_create_reference(self.env, self.ptr, initial_ref_count, &ptr)
        .check();

    return ptr.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_prototype
pub fn prototype(self: Object) !Val {
    var res: ?Val = null;
    try n.napi_get_prototype(self.env, self.ptr, &res).check();

    return res.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_object_seal
pub fn seal(self: Object) !void {
    try n.napi_object_seal(self.env, self.ptr).check();
}

/// Sets a property value on the object, identified by either a native string
/// key [1], or a JS value key [2].
///
/// - [1] https://nodejs.org/docs/latest/api/n-api.html#napi_set_named_property
/// - [2] https://nodejs.org/docs/latest/api/n-api.html#napi_set_property
pub fn set(self: Object, key: anytype, val: anytype) !void {
    switch (@TypeOf(key)) {
        Val => try n.napi_set_property(
            self.env,
            self.ptr,
            key,
            try self.env.infer(val),
        ).check(),

        else => try n.napi_set_named_property(
            self.env,
            self.ptr,
            @as([:0]const u8, key).ptr,
            try self.env.infer(val),
        ).check(),
    }
}

/// Compares the given `tag` with an existing tag on this object, if any,
/// and returns `true` iff it is a match.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_check_object_type_tag
pub fn tagCheck(self: Object, tag: *const Tag) !bool {
    var res: bool = false;
    try n.napi_check_object_type_tag(self.env, self.ptr, tag, &res).check();

    return res;
}

/// Associates the given `tag` with this object. `tagCheck()` can then be used
/// later on to verify that an object has a matching type tag.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_type_tag_object
pub fn tagSet(self: Object, tag: *const Tag) !void {
    try n.napi_type_tag_object(self.env, self.ptr, tag).check();
}

/// Creates an instance of the given type, with field values extracted from this
/// object.
///
/// Optional fields will be set to `null` if the corresponding JS property value
/// is `null` or `undefined` in JS object. An error is returned for all other
/// missing fields.
pub inline fn to(self: Object, comptime Struct: type) !Struct {
    const fields = @typeInfo(Struct).@"struct".fields;

    var result: Struct = undefined;
    inline for (fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "this")) {
            @field(result, field.name) = self.ptr;
            continue;
        }

        const is_optional = comptime switch (@typeInfo(field.type)) {
            .optional => true,
            else => false,
        };

        const val = try self.get(field.name);

        if ((comptime is_optional) and try val.isNullOrUndefined(self.env)) {
            @field(result, field.name) = null;
        } else {
            // [TODO] Provide a way to bubble up additional error data to the
            // callback handler, instead of logging here.
            @field(result, field.name) = val.to(
                self.env,
                field.type,
            ) catch |err| switch (err) {
                Err.PendingException => return err,
                else => {
                    log.err("[{t}] Error at field `{s}` of type `{s}`", .{
                        err, field.name, @typeName(Struct),
                    });

                    return err;
                },
            };
        }
    }

    return result;
}

/// Retrieves a native instance that was previously wrapped in this object
/// using `wrap()`.
///
/// > #### ⚠ NOTE
/// > The type, `T`, must contain a `comptime js_tag: Object.Tag`
/// field, which is first checked against the tag, if any, on the JS object.
/// This is to ensure that the native pointer can be safely unwrapped and cast
/// as `T`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_unwrap
pub fn unwrap(self: Object, comptime T: type) !?T {
    if (!try self.tagCheck(Tag.require(T))) return null;

    var res: ?T = null;
    n.napi_unwrap(self.env, self.ptr, @ptrCast(&res)).check() catch |err| {
        return switch (err) {
            Err.InvalidArg => null,
            else => err,
        };
    };

    return res.?;
}

/// Wraps a native `instance` in this object.
/// The native instance can be retrieved later using `unwrap()`.
///
/// > #### ⚠ NOTE
/// > `instance` must contain a `comptime js_tag: Object.Tag` field.
/// This is to ensure that the native pointer can later be safely unwrapped and
/// cast back into an instance of the same type.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_wrap
pub fn wrap(
    self: Object,
    instance: anytype,
    finalizer_partial: Finalizer.Partial(@TypeOf(instance)),
) !?Ref(Object) {
    try self.tagSet(Tag.require(@TypeOf(instance)));

    var ref_ptr: ?Ref(Object) = null;
    try n.napi_wrap(
        self.env,
        self.ptr,
        instance,
        finalizer_partial.finalizer.cb,
        finalizer_partial.finalizer.hint,
        if (finalizer_partial.finalizer.cb) |_| &ref_ptr else null,
    ).check();

    return ref_ptr;
}

/// Retrieves a native instance that was previously wrapped in this object
/// using `wrap()`, if any, and removes the wrapping.
///
/// If a finalize callback was associated with the wrapping, it will no
/// longer be called when the JavaScript object becomes garbage-collected.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_remove_wrap
pub fn wrapGetAndRemove(self: Object, comptime T: type) !?T {
    if (!try self.tagCheck(Tag.require(T))) return null;

    var res: ?T = null;
    n.napi_remove_wrap(self.env, self.ptr, @ptrCast(&res)).check() catch |err| {
        return switch (err) {
            Err.InvalidArg => null,
            else => err,
        };
    };

    return res.?;
}

/// Retrieves a native instance that was previously wrapped in this object
/// using `wrap()` and removes the wrapping.
///
/// If a finalize callback was associated with the wrapping, it will no
/// longer be called when the JavaScript object becomes garbage-collected.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_remove_wrap
pub fn wrapRemove(self: Object) !void {
    var res: ?AnyPtr = null;
    n.napi_remove_wrap(self.env, self.ptr, &res).check() catch |err| {
        return switch (err) {
            Err.InvalidArg => {},
            else => err,
        };
    };
}
