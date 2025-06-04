const Date = @import("Date.zig");
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// The Unix timestamp, in milliseconds, for a JS [Date](https://mdn.io/Date)
/// value, with leap seconds ignored. Returns an error for non-`Date` values.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_date_value
pub fn date(self: Val, env: Env) !Date {
    var unix_ms: f64 = undefined;
    try n.napi_get_date_value(env, self, &unix_ms).check();

    return .{ .timestamp_ms = unix_ms };
}

/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_date
pub fn isDate(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_date(env, self, &res).check();

    return res;
}
