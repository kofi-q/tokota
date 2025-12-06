//! Represents a global or local JS [Symbol](https://mdn.io.Symbol).
//!
//! Can be:
//! - Newly allocated via `Env.symbol()` or `Env.symbolFor()` (the latter will
//!   first try to retrieve an existing Symbol for the given key if one exists).
//! - Derived from an existing JS value handle via `Val.symbol()`.
//! - Received as native callback function argument.

const std = @import("std");

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

const Symbol = @This();

env: Env,
ptr: Val,

/// Creates a `Ref` from which the `Symbol` can later be extracted, outside
/// of the function scope within which it was initially created or received.
///
/// > #### ⚠ NOTE
/// > References prevent a JS value from being garbage collected. A
/// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
/// proper disposal.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
pub fn ref(self: Symbol, initial_ref_count: u32) !Ref(Symbol) {
    var ptr: ?Ref(Symbol) = null;
    try n.napi_create_reference(
        self.env,
        self.ptr,
        initial_ref_count,
        @ptrCast(&ptr),
    ).check();

    return ptr.?;
}
