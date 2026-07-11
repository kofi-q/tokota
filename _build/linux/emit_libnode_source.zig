const std = @import("std");

const napi = @import("tokota").napi;

comptime {
    @import("tokota").exportModule(@This());
}

pub fn emit() !void {
    const decls = @typeInfo(napi).@"struct".decl_names;

    const symbols = comptime blk: {
        var symbols: [decls.len][]const u8 = undefined;
        var len = 0;
        for (decls) |d| switch (@typeInfo(@TypeOf((@field(napi, d))))) {
            .@"fn" => {
                symbols[len] = d;
                len += 1;
            },
            else => {},
        };

        break :blk symbols[0..len].*;
    };

    const allo = std.heap.smp_allocator;

    var io_threaded = std.Io.Threaded.init(allo, .{ .environ = .empty });
    defer io_threaded.deinit();

    const io = io_threaded.io();

    var buf: [1024]u8 = undefined;
    var std_out = std.Io.File.stdout().writer(io, &buf);

    for (symbols) |symbol| try std_out.interface.print(
        \\export fn {s}() void {{}}
        \\
    , .{symbol});

    try std_out.interface.flush();
}
