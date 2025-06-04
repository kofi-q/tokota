//! Represents a JS `Class`[1] constructor. Enables
//! creation of new class instance objects.
//!
//! `Class` constructors can be created with `Env.class()`, or cast from an
//! existing JS `Val` with `Val.class()`.
//!
//! `Class` instances can be created with `new()`.
//!
//! > ### TIP
//! > When defining new `Class`es, it may be more convenient to create an
//! auto-exportable class type with `ClassZ`.
//!
//! - [1] https://mdn.io/Class

const argValues = @import("../function/args.zig").argValues;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Object = @import("Object.zig");
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

const Class = @This();

/// Environment within which this JS `Class` was created.
env: Env,

/// Pointer to the underlying JS `Class`.
ptr: Val,

/// Returns a new instance of this `Class`. Equivalent to
/// `new Class(args...)` in JS.
///
/// `args` may be a single argument of any type that can be converted to a JS
/// `Val`, or a tuple of one or more arguments.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn getUrl(call: t.Call) !t.Object {
///     const url_ctor = try call.env.run("URL");
///     const URL = url_ctor.class(call.env);
///
///     return URL.new("https://example.com");
/// }
///```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_new_instance
pub fn new(self: Class, args: anytype) !Object {
    const args_js = try argValues(self.env, args);

    var ptr: ?Val = null;
    try n.napi_new_instance(self.env, self.ptr, args_js.len, args_js.ptr, &ptr)
        .check();

    return .{ .env = self.env, .ptr = ptr.? };
}

/// Creates a `Ref` from which the `Class` can later be extracted, outside of
/// the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: Class, initial_ref_count: u32) !Ref(Class) {
    var ptr: ?Ref(Class) = null;
    try n.napi_create_reference(self.env, self.ptr, initial_ref_count, &ptr)
        .check();

    return ptr.?;
}
