const n = @import("../napi.zig");
const t = @import("../root.zig");

pub extern fn napi_create_date(env: t.Env, unix_ms: f64, res: *?t.Val) n.Status;

pub extern fn napi_get_date_value(env: t.Env, val: t.Val, res: *f64) n.Status;

pub extern fn napi_is_date(env: t.Env, val: t.Val, is_date: *bool) n.Status;
