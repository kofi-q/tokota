const std = @import("std");

const t = @import("tokota");

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModule(@This());
}

pub fn dateFromUnixMillis(timestamp_ms: f64) !t.Date {
    return .{ .timestamp_ms = timestamp_ms };
}

pub fn dateToUnixMillis(date: t.Date) !f64 {
    return date.timestamp_ms;
}

pub fn isDate(call: t.Call, val: t.Val) !bool {
    return val.isDate(call.env);
}
