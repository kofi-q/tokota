const builtin = @import("builtin");
const std = @import("std");

pub const Options = @import("options").Options;

pub const tokota_options = Options{
    .allow_external_buffers = true,
    .napi_version = .v10,
};

pub fn main() !void {
    var buf_stderr: [1024]u8 = undefined;
    var std_err = std.fs.File.stderr().writer(&buf_stderr).interface;

    var buf_stdout: [1024]u8 = undefined;
    var std_out = std.fs.File.stdout().writer(&buf_stdout).interface;

    var had_failures = false;

    for (builtin.test_functions) |t| {
        t.func() catch |err| {
            had_failures = true;
            try std.Io.Writer.print(
                &std_err,
                "  " ++ icon.fail ++ " {s}: " ++ color.red("{}") ++ "\n",
                .{ t.name, err },
            );
            continue;
        };

        try std.Io.Writer.print(
            &std_out,
            "  " ++ icon.pass ++ " {s}\n",
            .{t.name},
        );
    }

    if (had_failures) {
        try std.Io.Writer.print(&std_err, "{s} One or more tests failed.\n", .{
            icon.fail,
        });

        return;
    }

    try std.Io.Writer.print(&std_out, "{s} Done\n", .{icon.pass});

    try std_out.flush();
    try std_err.flush();
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
