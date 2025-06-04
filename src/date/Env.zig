//! `Env` API methods for JS `Date`s.

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// Returns a newly allocated JS [Date](https://mdn.io/Date) object set to the
/// given Unix millisecond timestamp.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_date
pub fn date(self: Env, timestampMs: f64) !Val {
    var ptr: ?Val = null;
    try n.napi_create_date(self, timestampMs, &ptr).check();

    return ptr.?;
}
