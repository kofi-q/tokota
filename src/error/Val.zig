const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// https://nodejs.org/docs/latest/api/n-api.html#napi_is_error
pub fn isError(self: Val, env: Env) !bool {
    var res: bool = undefined;
    try n.napi_is_error(env, self, &res).check();

    return res;
}
