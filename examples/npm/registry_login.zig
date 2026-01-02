const std = @import("std");
const allo = std.heap.smp_allocator;

pub fn main() !void {
    var io_threaded = std.Io.Threaded.init(allo, .{});
    defer io_threaded.deinit();

    const io = io_threaded.ioBasic();

    var child = std.process.Child.init(
        &.{ "npm", "adduser", "--registry", "http://localhost:4873" },
        allo,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.stdin_behavior = .Pipe;

    try child.spawn(io);

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
