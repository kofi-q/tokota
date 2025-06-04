const std = @import("std");

var rt: ?Runtime = null;
var rtInit = std.once(Runtime.init);

pub fn runtime() Runtime {
    rtInit.call();
    return rt.?;
}

pub const Runtime = enum {
    bun,
    deno,
    node,

    fn init() void {
        var buf: [16]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const allo = fba.allocator();

        const env_var = std.process.getEnvVarOwned(
            allo,
            "RUNTIME",
        ) catch unreachable;

        rt = std.meta.stringToEnum(Runtime, env_var).?;
    }
};
