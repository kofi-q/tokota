//! `Env` API methods for creating JS `Object`/`Class` values and properties.

const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Class = @import("Class.zig");
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const napiCb = @import("../root.zig").napiCb;
const Object = @import("Object.zig");
const Property = @import("property.zig").Property;
const requireNapiVersion = @import("../features.zig").requireNapiVersion;
const Val = @import("../root.zig").Val;

/// Creates a JS `Object` "API" with method and value properties corresponding
/// to public decls in the given `Struct` type. If non-void, `method_data` can
/// be bound to each exported method and later retrieved from incoming JS calls
/// via `CallT.data()`.
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
///     client = .{ .id = 1996 };
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
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_object
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_define_properties
pub fn api(self: Env, comptime Struct: type, method_data: anytype) !Object {
    const obj = try self.object();
    try obj.defineApi(Struct, method_data);

    return obj;
}

/// Defines a JS `Class` constructor that can be used to create new instances
/// in both native code, via `Class.new()`, and JS, via `new Class()`.
///
/// `constructor` is a Zig function following the Tokota callback pattern:
/// receives any number of arguments, corresponding to the class construction
/// arguments passed in from JS, and returns JS value corresponding to the
/// new class instance.
///
/// This is used internally by `ClassZ`, which may be more convenient, depending
/// on the use case.
///
/// > #### ⚠ NOTE
/// > The constructor is called with an already constructed instance of the
/// class, which can be retrieved via `Call.this()`. That object can then be
/// modified as needed and then returned to JS.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// var light_switch: LightSwitch = undefined;
///
/// pub const LightSwitch = struct {
///     /// A type tag is required when wrapping a native object in a JS class.
///     /// See `Object.Tag`.
///     comptime js_tag: t.Object.Tag = .{ .lower = 0xcafe, .upper = 0xf00d },
///
///     on: bool,
///
///     fn constructor(call: t.Call, initially_on: bool) !t.Object {
///         // The newly constructed class instance.
///         const this = try call.this();
///
///         // In the constructor, you can set properties on and/or attach
///         // native data to the new instance for use in later method calls.
///         light_switch = .{ .on = initially_on };
///         _ = try this.wrap(&light_switch, .with(deinit));
///
///         return this;
///     }
///
///     fn deinit(self: *LightSwitch, _: t.Env) !void {
///         self.* = undefined;
///     }
///
///     fn toggle(call: t.Call) !bool {
///         // Extract the previously wrapped native data instance.
///         const self = try call.thisUnwrap(*LightSwitch) orelse {
///             return error.InvalidLightSwitchInstance;
///         };
///         self.on = !self.on;
///
///         return self.on;
///     }
///
///     /// Export this type as a class in custom `toJs()` function.
///     pub fn toJs(env: t.Env) !t.Val {
///         const ctor = try env.class("LightSwitch", constructor, &.{
///             .method("toggle", toggle, .{}),
///         });
///
///         return ctor.ptr;
///     }
/// };
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const { LightSwitch } = require("./addon.node");
///
/// const lightSwitch = new LightSwitch(true);
/// assert(lightSwitch instanceof LightSwitch);
/// assert.equal(lightSwitch.toggle(), false);
/// assert.equal(lightSwitch.toggle(), true);
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_define_class
pub fn class(
    self: Env,
    name: []const u8,
    comptime constructor: anytype,
    props: []const Property,
) !Class {
    var ptr: ?Val = null;
    try n.napi_define_class(
        self,
        name.ptr,
        name.len,
        napiCb(constructor, .{}),
        null,
        props.len,
        props.ptr,
        &ptr,
    ).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// Defines a JS `Class` constructor that can be used to create new instances
/// in both native code, via `Class.new()`, and JS, via `new Class()`.
///
/// `constructor` is a Zig function following the Tokota callback pattern:
/// receives any number of arguments, corresponding to the class construction
/// arguments passed in from JS, and returns JS value corresponding to the
/// new class instance.
///
/// `data` is a native pointer to data that will be bound to the constructor
/// function and can be later extracted via `CallT.data()` if
/// `CallT(@TypeOfData)` is received as the first constructor argument.
///
/// This is used internally by `ClassZ`, which may be more convenient, depending
/// on the use case.
///
/// > #### ⚠ NOTE
/// > The constructor is called with an already constructed instance of the
/// class, which can be retrieved via `Call.this()`. That object can then be
/// modified as needed and then returned to JS.
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
/// var light_switch: LightSwitch = undefined;
///
/// pub const LightSwitch = struct {
///     /// A type tag is required when wrapping a native object in a JS class.
///     /// See `Object.Tag`.
///     comptime js_tag: t.Object.Tag = .{ .lower = 0xcafe, .upper = 0xf00d },
///
///     on: bool,
///
///     const CtorData = struct { foo: u32 };
///     var ctor_data = CtorData{ .foo = 500 };
///
///     fn constructor(call: t.CallT(*CtorData), initially_on: bool) !t.Object {
///         // The newly constructed class instance.
///         const this = try call.this();
///
///         // Constructor data, previously bound in `toJs()`.
///         const data = try call.data() orelse return error.MissingCtorData;
///         std.debug.assert(data == &ctor_data);
///
///         // In the constructor, you can set properties on and/or attach
///         // native data to the new instance for use in later method calls.
///         light_switch = .{ .on = initially_on };
///         _ = try this.wrap(&light_switch, .with(deinit));
///
///         return this;
///     }
///
///     fn deinit(self: *LightSwitch, _: t.Env) !void {
///         self.* = undefined;
///     }
///
///     fn toggle(call: t.Call) !bool {
///         // Extract the previously wrapped native data instance.
///         const self = try call.thisUnwrap(*LightSwitch) orelse {
///             return error.InvalidLightSwitchInstance;
///         };
///         self.on = !self.on;
///
///         return self.on;
///     }
///
///     /// Export this type as a class in custom `toJs()` function.
///     pub fn toJs(env: t.Env) !t.Val {
///         const ctor = try env.classT("LightSwitch", constructor, &ctor_data, &.{
///             .method("toggle", toggle, .{}),
///         });
///
///         return ctor.ptr;
///     }
/// };
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const { LightSwitch } = require("./addon.node");
///
/// const lightSwitch = new LightSwitch(true);
/// assert(lightSwitch instanceof LightSwitch);
/// assert.equal(lightSwitch.toggle(), false);
/// assert.equal(lightSwitch.toggle(), true);
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_define_class
pub fn classT(
    self: Env,
    name: []const u8,
    comptime constructor: anytype,
    data: anytype,
    props: []const Property,
) !Class {
    var ptr: ?Val = null;
    try n.napi_define_class(
        self,
        name.ptr,
        name.len,
        napiCb(constructor, .{ .DataType = @TypeOf(data) }),
        data,
        props.len,
        props.ptr,
        &ptr,
    ).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_object
pub fn enumObject(self: Env, comptime E: type) !Object {
    const info = switch (@typeInfo(E)) {
        .@"enum" => |info| info,
        else => @compileError("Enum type required"),
    };

    var props: [info.fields.len]Property = undefined;

    inline for (info.fields, 0..) |field, i| props[i] = .value(
        field.name,
        try self.infer(@as(info.tag_type, field.value)),
        .{},
    );

    return self.objectDefine(&props);
}

/// Returns a newly allocated, empty JS `Object`. Properties can be set on the
/// object via `Object.set()`, `Object.define()`, or `Object.defineApi()`.
///
/// Methods like `Env.objectDefine()`, `Env.objectFrom()`, and `Env.api()` may
/// be more convenient, depending on the use case.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_object
pub fn object(self: Env) !Object {
    var ptr: ?Val = null;
    try n.napi_create_object(self, &ptr).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// Returns a newly allocated JS `Object` with the given properties defined.
///
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_object
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_define_properties
pub fn objectDefine(self: Env, props: []const Property) !Object {
    var ptr: ?Val = null;
    try n.napi_create_object(self, &ptr).check();

    const obj = Object{ .ptr = ptr.?, .env = self };
    try obj.define(props);

    return obj;
}

/// Returns a newly allocated JS `Object` with properties defined according to
/// fields of `obj_struct`.
///
/// This differs from `Env.api()` in that it operates on fields of struct
/// instances, whereas `Env.api()` converts public decls on the struct type.
///
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_create_object
/// - https://nodejs.org/docs/latest/api/n-api.html#napi_define_properties
pub fn objectFrom(self: Env, obj_struct: anytype) !Object {
    var ptr: ?Val = null;
    try n.napi_create_object(self, &ptr).check();

    const obj = Object{ .ptr = ptr.?, .env = self };
    try obj.from(obj_struct);

    return obj;
}

/// https://nodejs.org/docs/latest/api/n-api.html#node_api_create_property_key_utf8
pub fn propKey(self: Env, str: []const u8) !Val {
    requireNapiVersion(.v10);

    var val: ?Val = null;
    try n.node_api_create_property_key_utf8(self, str.ptr, str.len, &val)
        .check();

    return val.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#node_api_create_property_key_latin1
pub fn propKeyLatin1(self: Env, str: []const u8) !Val {
    requireNapiVersion(.v10);

    var val: ?Val = null;
    try n.node_api_create_property_key_latin1(self, str.ptr, str.len, &val)
        .check();

    return val.?;
}

/// https://nodejs.org/docs/latest/api/n-api.html#node_api_create_property_key_utf16
pub fn propKeyUtf16(self: Env, str: []const u16) !Val {
    requireNapiVersion(.v10);

    var val: ?Val = null;
    try n.node_api_create_property_key_utf16(self, str.ptr, str.len, &val)
        .check();

    return val.?;
}
