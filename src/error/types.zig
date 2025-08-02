const std = @import("std");

const Env = @import("../root.zig").Env;
const NapiStatus = @import("../root.zig").NapiStatus;
const Val = @import("../root.zig").Val;

/// Additional info about the last Node-API error, available via
/// `Env.lastNapiErr()` immediately after an error is received.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_extended_error_info
pub const ErrorInfo = extern struct {
    /// UTF8-encoded string containing a VM-neutral description of the error.
    ///
    /// Points to a statically-defined string - safe to use beyond the lifetime
    /// of `ErrorInfo`, whose remaining fields will be overwritten by successive
    /// Node-API calls.
    msg: [*:0]const u8,

    /// Reserved for VM-specific error details. This is currently not
    /// implemented for any VM.
    _engine_reserved: ?*anyopaque,

    /// VM-specific error code. This is currently not implemented for any VM.
    _engine_code: u32,

    /// The Node-API status code that originated with the last error.
    code: NapiStatus,

    pub fn format(
        self: ErrorInfo,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: std.Io.AnyWriter,
    ) !void {
        try std.fmt.format(writer, "[{}] {s}", .{ self.code, self.msg });
    }
};

pub const ErrorDetails = struct {
    code: ?[:0]const u8 = null,
    msg: [:0]const u8,

    pub fn format(
        self: ErrorDetails,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: std.Io.AnyWriter,
    ) !void {
        try std.fmt.format(writer, "[{}] {s}", .{ self.code, self.msg });
    }
};
