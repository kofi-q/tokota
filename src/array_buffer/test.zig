const std = @import("std");
const t = @import("tokota");

const tests = @import("test_cases.zig");

pub const tokota_options = t.Options{
    .allow_external_buffers = true,
    .napi_version = .v8,
};

comptime {
    t.exportModuleWithInit(@This(), tests.InstanceData.init);
}

pub const ArrayBuffers = tests.ArrayBuffers;
pub const Buffers = tests.Buffers;
pub const DataViews = tests.DataViews;
pub const TypedArrays = tests.TypedArrays;
