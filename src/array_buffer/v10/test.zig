const std = @import("std");
const t = @import("tokota");

const tests = @import("test_cases.zig");

pub const tokota_options = t.Options{
    .allow_external_buffers = true,
    .napi_version = .v10,
};

comptime {
    t.exportModuleWithInit(@This(), tests.InstanceData.init);
}

pub const ArrayBuffers = tests.ArrayBuffers;
pub const Buffers = tests.Buffers;
pub const DataViews = tests.DataViews;
pub const TypedArrays = tests.TypedArrays;

pub const BuffersV10 = struct {
    pub fn fromArrayBuffer(buf: t.ArrayBuffer, values: t.Array) !t.Buffer {
        const len = try values.len();
        const node_buffer = try buf.buffer(0, len);

        for (0..len) |i| node_buffer.data[i] = try values.getT(i, u8);

        return node_buffer;
    }
};
