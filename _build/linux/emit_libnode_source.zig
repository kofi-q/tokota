const std = @import("std");

const napi = @import("tokota").napi;

comptime {
    @import("tokota").exportModule(@This());
}

pub fn emit() !void {
    const decls = @typeInfo(napi).@"struct".decls;

    const symbols = comptime blk: {
        var symbols: [decls.len][]const u8 = undefined;
        var len = 0;
        for (decls) |d| switch (@typeInfo(@TypeOf((@field(napi, d.name))))) {
            .@"fn" => {
                symbols[len] = d.name;
                len += 1;
            },
            else => {},
        };

        break :blk symbols[0..len].*;
    };

    const std_out = std.io.getStdOut().writer();

    for (symbols) |symbol| try std_out.print(
        \\export fn {s}() void {{}}
        \\
    , .{symbol});
}
