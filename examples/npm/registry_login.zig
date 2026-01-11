const std = @import("std");
const allo = std.heap.smp_allocator;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var child = try std.process.spawn(io, .{
        .argv = &.{ "npm", "adduser", "--registry", "http://localhost:4873" },
        .stderr = .pipe,
        .stdin = .pipe,
        .stdout = .pipe,
        .environ_map = init.environ_map,
    });

    const stdout = blk: {
        var buf: [64]u8 = undefined;
        var r = child.stdout.?.reader(io, &buf);
        break :blk &r.interface;
    };

    var stdin_writer = child.stdin.?.writer(io, &.{});
    const stdin = &stdin_writer.interface;

    try stdout.fillMore();
    try stdout.fillMore();
    while (stdout.bufferedLen() > 0) : (try stdout.fillMore()) {
        _ = std.mem.find(u8, stdout.buffered(), "Username:") orelse continue;

        try stdin.writeAll("tokota\n");
        stdout.tossBuffered();
        break;
    }

    try stdout.fillMore();
    while (stdout.bufferedLen() > 0) : (try stdout.fillMore()) {
        _ = std.mem.find(u8, stdout.buffered(), "Password:") orelse continue;

        try stdin.writeAll("tokota\n");
        stdout.tossBuffered();
        break;
    }

    try stdout.fillMore();
    while (stdout.bufferedLen() > 0) : (try stdout.fillMore()) {
        _ = std.mem.find(u8, stdout.buffered(), "Email:") orelse continue;

        try stdin.writeAll("tokota@example.com\n");
        stdout.tossBuffered();
        break;
    }

    _ = try child.wait(io);
}
