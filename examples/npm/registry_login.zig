const std = @import("std");
const allo = std.heap.smp_allocator;

pub fn main() !void {
    var child = std.process.Child.init(
        &.{ "npm", "adduser", "--registry", "http://localhost:4873" },
        allo,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.stdin_behavior = .Pipe;

    try child.spawn();

    var buf: [1024]u8 = undefined;
    var std_out = child.stdout.?;
    var output_len = try std_out.read(&buf);

    while (output_len > 0) : (output_len = try std_out.read(&buf)) {
        if (std.mem.startsWith(u8, buf[0..output_len], "Username:")) {
            try child.stdin.?.writeAll("tokota\n");
            break;
        }
    }

    while (output_len > 0) : (output_len = try std_out.read(&buf)) {
        if (std.mem.startsWith(u8, buf[0..output_len], "Password:")) {
            try child.stdin.?.writeAll("tokota\n");
            break;
        }
    }

    while (output_len > 0) : (output_len = try std_out.read(&buf)) {
        if (std.mem.startsWith(u8, buf[0..output_len], "Email:")) {
            try child.stdin.?.writeAll("tokota@example.com\n");
            break;
        }
    }

    _ = try child.wait();
}
