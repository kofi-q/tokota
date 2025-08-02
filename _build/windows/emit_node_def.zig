//! Creates a Windows `.def` module-definition file containing all referenced
//! Node-API symbols from the library.
//!
//! The `.def` file is later used to create a stub DLL to link against.

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

    var buf: [1024]u8 = undefined;
    var std_out = std.fs.File.stdout().writer(&buf);

    try std_out.interface.writeAll(
        \\EXPORTS
        \\
    );

    for (symbols) |symbol| try std_out.interface.print(
        \\    {s}
        \\
    , .{symbol});

    try std_out.interface.flush();
}
