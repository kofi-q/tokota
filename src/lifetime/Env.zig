//! `Env` API methods for managing lifetimes of JS value handles.

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const HandleScope = @import("handle_scope.zig").HandleScope;
const HandleScopeEscapable = @import("handle_scope.zig").HandleScopeEscapable;
const Ref = @import("ref.zig").Ref;
const Val = @import("../root.zig").Val;

/// Creates a new lifetime scope for handles to JS values. Any value handles
/// created (by creating a new value, or extracting one from an object or call
/// arguments) will be associated with the new scope and only stay valid until
/// `HandleScope.close()` is called, at which point, they will be released and
/// can be garbage collected.
///
/// This is especially useful when creating large amounts of handles in a loop,
/// where only one handle is in use at any point in time, in which case, it's
/// beneficial to create limited scope within the loop to avoid keeping all the
/// handles from previous iterations alive in memory.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn sumLarge(call: t.Call, values: t.Array) !t.Uint {
///     var sum: t.Uint = 0;
///
///     for (0..1_000_000) |i| {
///         const scope = try call.env.handleScope();
///         defer scope.close() catch |err| t.panic(
///             "Unable to close handle scope",
///             @errorName(err),
///         );
///
///         sum += try values.getT(i, ?u32) orelse break;
///     }
///
///     return sum;
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_open_handle_scope
pub fn handleScope(env: Env) !HandleScope {
    var ptr: ?n.HandleScope = null;
    try n.napi_open_handle_scope(env, &ptr).check();

    return .{ .ptr = ptr.?, .env = env };
}

/// Creates a new lifetime scope for handles to JS values. Any value handles
/// created (by creating a new value, or extracting one from an object or call
/// arguments) will be associated with the new scope and only stay valid until
/// `HandleScopeEscapable.close()` is called, at which point, they will be
/// released and can be garbage collected.
///
/// This is especially useful when creating large amounts of handles in a loop,
/// where only one handle is in use at any point in time, in which case, it's
/// beneficial to create limited scope within the loop to avoid keeping all the
/// handles from previous iterations alive in memory.
///
/// Unlike `Env.handleScope()`, this creates a scope that enables "escaping" a
/// value out of the inner scope and into the parent scope of the native method
/// call via `HandleScopeEscapable.escape()`.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn find(call: t.Call, haystack: t.Array, needle: t.Val) !?t.Val {
///     var match: ?t.Val = null;
///
///     for (0..1_000_000) |i| {
///         const scope = try call.env.handleScopeEscapable();
///         defer scope.close() catch |err| t.panic(
///             "Unable to close handle scope",
///             @errorName(err),
///         );
///
///         const value = try haystack.get(i);
///         if (try value.eqlStrict(needle, call.env)) {
///             match = try scope.escape(value);
///             break;
///         }
///     }
///
///     doSomethingWithMatch(match);
///
///     return match;
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_open_escapable_handle_scope
pub fn handleScopeEscapable(self: Env) !HandleScopeEscapable {
    var ptr: ?n.HandleScopeEscapable = null;
    try n.napi_open_escapable_handle_scope(self, &ptr).check();

    return .{ .env = self, .ptr = ptr.? };
}
