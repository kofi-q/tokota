//! Creates a Windows `.def` module-definition file containing all referenced
//! Node-API symbols from the library.
//!
//! The `.def` file is later used to create a stub DLL to link against.

const std = @import("std");

const napi = @import("tokota").napi;

pub fn main() !void {
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
    try std_out.writeAll(
        \\EXPORTS
        \\
    );

    for (symbols) |symbol| {
        try std_out.print(
            \\    {s}
            \\
        , .{symbol});
    }
}
