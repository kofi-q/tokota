const std = @import("std");
const t = @import("tokota");

const tests = @import("test_cases.zig");

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModule(@This());
}

pub const Classes = tests.Classes;
pub const Objects = tests.Objects;
pub const RetroEncabulator = tests.RetroEncabulator;
pub const TurboEncabulator = tests.TurboEncabulator;
