const std = @import("std");
const Writer = std.Io.Writer;

const Env = @import("../root.zig").Env;
const Val = @import("../root.zig").Val;

/// Argument receiver for short, stack-allocated, UTF-8 strings.
///
/// Provides a convenient way to receive strings as function arguments when the
/// expected input has a known, relatively small upper bound.
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const t = @import("tokota");
///
/// pub fn hexToRgb(hex_color: t.TinyStr(7)) ![3]u8 {
///     const color_slice = hex_color.slice();
///     if (color_slice[0] != '#') return error.InvalidColorFormat;
///
///     return .{
///         try std.fmt.parseInt(u8, color_slice[1..3], 16),
///         try std.fmt.parseInt(u8, color_slice[3..5], 16),
///         try std.fmt.parseInt(u8, color_slice[5..7], 16),
///     };
/// }
/// ```
///
/// > #### ⚠ NOTE
/// > Input strings longer than `buffer_size` will be truncated without error.
pub fn TinyStr(comptime buffer_size: u8) type {
    return struct {
        buf: [buffer_size + 1]u8,
        len: u8,

        pub fn format(self: @This(), writer: *Writer) Writer.Error!void {
            try writer.writeAll(self.slice());
        }

        pub inline fn fromJs(env: Env, val: Val) !@This() {
            var str = @This(){ .buf = undefined, .len = 0 };
            const result = try val.stringBuf(env, &str.buf);
            str.len = @intCast(result.len);

            return str;
        }

        pub fn slice(self: *const @This()) [:0]const u8 {
            return self.buf[0..self.len :0];
        }

        pub inline fn toJs(self: @This(), env: Env) !Val {
            return env.string(self.slice());
        }
    };
}
