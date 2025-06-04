const Env = @import("../root.zig").Env;
const options = @import("../root.zig").options;
const Val = @import("../root.zig").Val;

const Resource = @This();

name: []const u8,
ptr: ?Val = null,

pub const default = Resource{
    .name = "[" ++ options.lib_name ++ "] Async task",
};

pub fn nameVal(self: @This(), env: Env) !Val {
    return env.string(self.name);
}
