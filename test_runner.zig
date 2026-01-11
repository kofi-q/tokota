const builtin = @import("builtin");
const std = @import("std");

pub const Options = @import("options").Options;

pub const tokota_options = Options{
    .allow_external_buffers = true,
    .napi_version = .v10,
};

// [FIXME] No longer printing test names for failed test cases.
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stderr = blk: {
        var buf: [1024]u8 = undefined;
        var writer = std.Io.File.stderr().writer(io, &buf);
        break :blk &writer.interface;
    };

    var stdout = blk: {
        var buf: [1024]u8 = undefined;
        var writer = std.Io.File.stdout().writer(io, &buf);
        break :blk &writer.interface;
    };

    var had_failures = false;

    for (builtin.test_functions) |t| {
        t.func() catch |err| {
            had_failures = true;
            try stderr.print("  {s} {s}: " ++ color.red("{}") ++ "\n", .{
                icon.fail, t.name, err,
            });
            continue;
        };

        try stdout.print("  " ++ icon.pass ++ " {s}\n", .{t.name});
    }

    if (had_failures) return stderr.print(
        "{s} One or more tests failed.\n",
        .{icon.fail},
    );

    try stdout.print("{s} Done\n", .{icon.pass});
    try stdout.flush();
    try stderr.flush();
}

const icon = struct {
    const fail = color.red("×");
    const pass = color.green("✔");
};

const color = struct {
    fn amber(comptime fmt: []const u8) []const u8 {
        return shade(33, fmt);
    }

    fn green(comptime fmt: []const u8) []const u8 {
        return shade(32, fmt);
    }

    fn shade(comptime code: u8, comptime fmt: []const u8) []const u8 {
        return std.fmt.comptimePrint("\x1b[1;{d}m{s}\x1b[0;0m", .{ code, fmt });
    }

    fn red(comptime fmt: []const u8) []const u8 {
        return shade(31, fmt);
    }
};
