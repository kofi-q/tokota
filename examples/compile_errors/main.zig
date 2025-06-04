const std = @import("std");
const t = @import("tokota");

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModule(@This());
}

const Opaque = opaque {};
const Struct = struct { foo: u32 };
const Union = union(enum) { a: u32, b: f32 };

pub const args = struct {
    pub fn unsupportedF32(_: f32) void {}
    pub fn unsupportedUnion(_: Union) void {}
    pub fn unsupportedPtr(_: *const Struct) void {}
    pub fn unsupportedOpaquePtr(_: *const Opaque) void {}
};

pub const buffers = struct {
    pub fn fromArrayBuffer(backing_buf: t.ArrayBuffer, len: u32) !t.Buffer {
        return backing_buf.buffer(0, len);
    }
};

pub const return_types = struct {
    pub fn unsupportedUnsafeComptimeInt() comptime_int {
        return std.math.maxInt(u64);
    }

    pub fn unsupportedIsize() usize {
        return 0xffff;
    }

    pub fn unsupportedUsize() usize {
        return 0xffff;
    }

    pub fn unsupportedUnion() Union {
        return .{ .a = 42 };
    }

    pub fn unsupportedPtr() *const Struct {
        return &.{ .foo = 1957 };
    }

    pub fn unsupportedOpaquePtr() *const Opaque {
        return @ptrCast(&Struct{ .foo = 1957 });
    }
};
