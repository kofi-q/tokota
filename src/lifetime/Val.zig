const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Ref = @import("ref.zig").Ref;
const requireNapiVersion = @import("../features.zig").requireNapiVersion;
const Val = @import("../root.zig").Val;

/// Creates a `Ref` from which the `Val` can later be extracted, outside of
/// the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: Val, env: Env, initial_ref_count: u32) !Ref(Val) {
    // Refs on types like string, number, boolean, etc, are only supported in
    // v10+. For previous versions, `fn ref()` methods are available on types
    // that support it.
    requireNapiVersion(.v10);

    var ptr: ?Ref(Val) = null;
    try n.napi_create_reference(env, self, initial_ref_count, &ptr).check();

    return ptr.?;
}
