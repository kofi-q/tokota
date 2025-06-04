const tokota = @import("tokota");

/// Override default options with a public `tokota_options` declaration in the
/// root file of the module.
pub const tokota_options = tokota.Options{
    .lib_name = "example-promise",
    .napi_version = .v8,
};

comptime {
    tokota.exportModule(@This());
}

pub const todoTotals = @import("managed_minimal.zig").todoTotals;
pub const todosForUser = @import("managed_extended.zig").todosForUser;
