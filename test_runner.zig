const builtin = @import("builtin");
const std = @import("std");

pub const Options = @import("options").Options;

pub const tokota_options = Options{
    .allow_external_buffers = true,
    .napi_version = .v10,
};

pub fn main() !void {
    const std_err = std.io.getStdErr().writer();
    const std_out = std.io.getStdOut().writer();
    var had_failures = false;

    for (builtin.test_functions) |t| {
        t.func() catch |err| {
            had_failures = true;
            try std.fmt.format(
                std_err,
                "  " ++ icon.fail ++ " {s}: " ++ color.red("{}") ++ "\n",
                .{ t.name, err },
            );
            continue;
        };

        try std.fmt.format(std_out, "  " ++ icon.pass ++ " {s}\n", .{t.name});
    }

    if (had_failures) {
        try std.fmt.format(std_err, "{s} One or more tests failed.\n", .{
            icon.fail,
        });

        return;
    }

    try std.fmt.format(std_out, "{s} Done\n", .{icon.pass});
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
