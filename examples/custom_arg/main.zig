const std = @import("std");
const tokota = @import("tokota");

comptime {
    tokota.exportModule(@This());
}

pub fn setTodoColor(color: Color) void {
    switch (color) {
        .hex => |hex| std.debug.print(
            "To-do color set to {s}!\n",
            .{hex},
        ),
        .rgb => |rgb| std.debug.print(
            "To-do color set to rgb({d}, {d}, {d})!\n",
            rgb,
        ),
    }
}

/// Unions have no built-in conversion to/from JS values in Tokota, to avoid
/// ambiguity. However, application-specific handling can be easily added.
const Color = union(enum) {
    const Rgb = struct { u8, u8, u8 };

    hex: []const u8,
    rgb: Rgb,

    /// Add a `pub fn fromJs(Env, Val) @This()` decl to any type to customize
    /// conversion from JS argument values.
    pub fn fromJs(env: tokota.Env, val: tokota.Val) !Color {
        switch (try val.typeOf(env)) {
            .string => return .{ .hex = try val.string(env, 7) },
            .object => return .{ .rgb = try val.object(env).to(Rgb) },
            else => return error.ExpectedHexStringOrRgbArray,
        }
    }
};
