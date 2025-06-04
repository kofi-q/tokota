const std = @import("std");
const t = @import("tokota");

const tests = @import("test_cases.zig");

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModuleWithInit(@This(), tests.init);
}

pub const HandleScopes = tests.HandleScopes;
pub const Refs = tests.Refs;
