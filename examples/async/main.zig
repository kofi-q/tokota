const tokota = @import("tokota");

/// Override default options with a public `tokota_options` declaration in the
/// root file of the module.
pub const tokota_options = tokota.Options{
    .lib_name = "example-async",
    .napi_version = .v8,
};

comptime {
    tokota.exportModule(@This());
}

pub const todoTotals = @import("minimal.zig").todoTotals;
pub const todosForUser = @import("extended.zig").todosForUser;
