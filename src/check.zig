const std = @import("std");

pub const napi = @import("napi.zig");
pub const tokota = @import("root.zig");

pub const tokota_options = tokota.Options{
    .allow_external_buffers = true,
    .napi_version = .v10,
};

comptime {
    refAllDeclsRecursive(@This());
}

/// Given a type, recursively references all the declarations inside, so that
/// the semantic analyzer sees them.
///
/// Copied from `std.testing`, to bypass the test-only restriction.
pub fn refAllDeclsRecursive(comptime T: type) void {
    inline for (comptime std.meta.declarations(T)) |decl| {
        if (@TypeOf(@field(T, decl)) == type) {
            switch (@typeInfo(@field(T, decl))) {
                .@"struct",
                .@"enum",
                .@"union",
                .@"opaque",
                => refAllDeclsRecursive(@field(T, decl)),
                else => {},
            }
        }

        // A little hacky, but this fn has a @compileError to guide usage.
        if (T == tokota.Call and std.mem.eql(u8, decl, "fromJs")) continue;

        _ = &@field(T, decl);
    }
}
