const std = @import("std");
const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub const InstanceData = struct {
    pub fn init(env: t.Env, exports: t.Val) !t.Val {
        try env.instanceDataSet(&InstanceData{}, .with(deinit));
        return exports;
    }

    fn deinit(_: *const InstanceData, _: t.Env) !void {
        return switch (dba.deinit()) {
            .ok => {},
            .leak => t.panic("Memory leak detected", null),
        };
    }
};

pub const ArrayBuffers = struct {
    pub fn create(call: t.Call, input: t.TypedArray(.u8)) !t.ArrayBuffer {
        return call.env.arrayBufferFrom(input.data);
    }

    const OwnedBuffer = struct {
        comptime js_tag: t.Object.Tag = .{
            .lower = 0xab6927a5f2f84a4f,
            .upper = 0x986239b4d2d02641,
        },
        buf: [16]u8,
    };

    pub fn createZigOwned(call: t.Call) !t.ArrayBuffer {
        const allo = dba.allocator();
        const native_data = try allo.create(OwnedBuffer);
        const native_buf = native_data.buf[0..4];

        @memcpy(native_buf, "\xca\xfe\xf0\x0d");

        const buffer = try call.env.arrayBufferOwned(
            native_buf,
            .withHinted(native_data, deinitZigOwned),
        );
        _ = try buffer.ptr.object(call.env).wrap(native_data, .none);

        return buffer;
    }

    pub fn assertZigOwned(
        call: t.Call,
        buf_js: t.ArrayBuffer,
        expected: t.TypedArray(.u8),
    ) !void {
        const buf_zig = try buf_js.ptr
            .object(call.env)
            .unwrap(*OwnedBuffer) orelse return error.InvalidBufferTypeTag;

        var err_buf: [128]u8 = undefined;

        if (&buf_zig.buf != buf_js.data.ptr) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = try std.fmt.bufPrintZ(&err_buf,
                \\
                \\Mismatched Buffer data pointer.
                \\Expected: {*}
                \\Actual:   {*}
            , .{
                &buf_zig.buf,
                buf_js.data.ptr,
            }),
        });

        if (!std.mem.eql(
            u8,
            buf_zig.buf[0..expected.data.len],
            expected.data,
        )) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = try std.fmt.bufPrintZ(&err_buf,
                \\
                \\Mismatched Buffer data.
                \\Expected: {x:0>2}
                \\Actual:   {x:0>2}
            , .{
                expected.data,
                buf_zig.buf[0..expected.data.len],
            }),
        });
    }

    fn deinitZigOwned(data_js: [*]u8, data_zig: *OwnedBuffer, _: t.Env) !void {
        const allo = dba.allocator();
        std.debug.assert(data_js == &data_zig.buf);
        allo.destroy(data_zig);
    }

    pub fn detach(call: t.Call, array_buffer: t.ArrayBuffer) !void {
        if (try array_buffer.isDetached()) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = "Expected non-detached ArrayBuffer as first argument",
        });

        try array_buffer.detach();
        if (!try array_buffer.isDetached()) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = "ArrayBuffer failed to detach",
        });
    }

    pub fn assertDetached(call: t.Call, array_buffer: t.ArrayBuffer) !void {
        if (!try array_buffer.isDetached()) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = "Expected detached ArrayBuffer",
        });
    }

    pub fn isArrayBuffer(call: t.Call, val: t.Val) !bool {
        return val.isArrayBuffer(call.env);
    }
};

pub const Buffers = struct {
    pub fn assertBuffer(call: t.Call, buffer: t.Buffer) !t.Buffer {
        if (!std.mem.eql(u8, buffer.data, "\xca\xfe\xf0\x0d")) {
            var buf: [64]u8 = undefined;

            return call.env.throwErr(.{
                .code = "AssertionFailed",
                .msg = try std.fmt.bufPrintZ(&buf,
                    \\
                    \\Expected: {{ ca, fe, f0, 0d }}
                    \\Actual: {x:0>2}
                , .{buffer.data}),
            });
        }

        return buffer;
    }

    pub fn create(call: t.Call, input: t.TypedArray(.u8)) !t.Buffer {
        const buffer = try call.env.buffer(input.data.len);
        @memcpy(buffer.data, input.data);

        return buffer;
    }

    const OwnedBuffer = struct {
        comptime js_tag: t.Object.Tag = .{
            .lower = 0x5c6bc0aaf16a4016,
            .upper = 0x80eb344d5e91b61b,
        },

        buf: [16]u8,
    };

    pub fn createZigOwned(call: t.Call) !t.Buffer {
        const allo = dba.allocator();
        const native_data = try allo.create(OwnedBuffer);
        const native_buf = native_data.buf[0..4];

        @memcpy(native_buf, "\xca\xfe\xf0\x0d");

        const buffer = try call.env.bufferOwned(
            native_buf,
            .withHinted(native_data, deinitZigOwned),
        );
        _ = try buffer.ptr.object(call.env).wrap(native_data, .none);

        return buffer;
    }

    pub fn assertZigOwned(
        call: t.Call,
        buf_js: t.Buffer,
        expected: t.TypedArray(.u8),
    ) !void {
        const buf_zig = try buf_js.ptr
            .object(call.env)
            .unwrap(*OwnedBuffer) orelse return error.InvalidBufferTypeTag;

        var err_buf: [128]u8 = undefined;

        if (&buf_zig.buf != buf_js.data.ptr) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = try std.fmt.bufPrintZ(&err_buf,
                \\
                \\Mismatched Buffer data pointer.
                \\Expected: {*}
                \\Actual:   {*}
            , .{
                &buf_zig.buf,
                buf_js.data.ptr,
            }),
        });

        if (!std.mem.eql(
            u8,
            buf_zig.buf[0..expected.data.len],
            expected.data,
        )) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = try std.fmt.bufPrintZ(&err_buf,
                \\
                \\Mismatched Buffer data.
                \\Expected: {x:0>2}
                \\Actual:   {x:0>2}
            , .{
                expected.data,
                buf_zig.buf[0..expected.data.len],
            }),
        });
    }

    fn deinitZigOwned(data_js: [*]u8, data_zig: *OwnedBuffer, _: t.Env) !void {
        const allo = dba.allocator();
        std.debug.assert(data_js == &data_zig.buf);
        allo.destroy(data_zig);
    }

    pub fn fromCopy(call: t.Call) !t.Buffer {
        return call.env.bufferFrom("\xca\xfe\xf0\x0d");
    }
};

pub const DataViews = struct {
    pub fn generate(call: t.Call) !t.DataView {
        const array_buffer = try call.env.arrayBuffer(20);

        for (0..array_buffer.data.len) |i| {
            array_buffer.data[i] = @intCast(i);
        }

        return array_buffer.dataView(0, 10);
    }

    pub fn getHttpBody(array_buffer: t.ArrayBuffer) !t.DataView {
        const end_of_header = "\r\n\r\n";
        const idx_eoh = std.mem.lastIndexOf(
            u8,
            array_buffer.data,
            end_of_header,
        ).?;

        const idx_start_of_body = idx_eoh + end_of_header.len;
        const body_len = std.mem.indexOf(
            u8,
            array_buffer.data[idx_start_of_body..],
            "\r\n",
        ).?;

        return array_buffer.dataView(idx_start_of_body, body_len);
    }

    pub fn backingArrayBuffer(call: t.Call, dataview: t.DataView) !t.Val {
        const value = std.mem.readInt(u16, dataview.data[0..2], .big);

        var buf: [64]u8 = undefined;
        if (value != 0x0405) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = try std.fmt.bufPrintZ(&buf,
                \\
                \\Expected: 0x0405
                \\Actual: 0x{x:0>4}
            , .{value}),
        });

        return dataview.buffer;
    }
};

pub const TypedArrays = struct {
    pub fn generateI8(call: t.Call) !t.TypedArray(.i8) {
        const array_buffer = try call.env.arrayBuffer(8);
        const typed_array = try array_buffer.typedArray(.i8, 2, 4);

        typed_array.data[0..4].* = .{ -0x0a, 0x0b, -0x0c, 0x0d };

        return typed_array;
    }

    pub fn generateI8Copy(call: t.Call) !t.TypedArray(.i8) {
        return call.env.typedArrayFrom(&[_]i8{ -0x0a, 0x0b, -0x0c, 0x0d });
    }

    pub fn generateU8(call: t.Call) !t.TypedArray(.u8) {
        const array_buffer = try call.env.arrayBuffer(8);
        const typed_array = try array_buffer.typedArray(.u8, 2, 4);

        typed_array.data[0..4].* = "\xca\xfe\xf0\x0d".*;

        return typed_array;
    }

    pub fn generateU8Copy(call: t.Call) !t.TypedArray(.u8) {
        return call.env.typedArrayFrom("\xca\xfe\xf0\x0d");
    }

    pub fn generateU8Clamped(call: t.Call) !t.TypedArray(.u8c) {
        const array_buffer = try call.env.arrayBuffer(8);
        const typed_array = try array_buffer.typedArray(.u8c, 2, 4);

        typed_array.data[0..4].* = "\xca\xfe\xf0\x0d".*;

        return typed_array;
    }

    pub fn generateI16(call: t.Call) !t.TypedArray(.i16) {
        const array_buffer = try call.env.arrayBuffer(16);
        const typed_array = try array_buffer.typedArray(.i16, 2, 4);

        typed_array.data[0..4].* = .{ -0x0abc, 0x0def, -0x0123, 0x0456 };

        return typed_array;
    }

    pub fn generateI16Copy(call: t.Call) !t.TypedArray(.i16) {
        return call.env.typedArrayFrom(
            &[_]i16{ -0x0abc, 0x0def, -0x0123, 0x0456 },
        );
    }

    pub fn generateU16(call: t.Call) !t.TypedArray(.u16) {
        const array_buffer = try call.env.arrayBuffer(16);
        const typed_array = try array_buffer.typedArray(.u16, 2, 4);

        typed_array.data[0..4].* = .{ 0xcafe, 0xf00d, 0xc001, 0xface };

        return typed_array;
    }

    pub fn generateU16Copy(call: t.Call) !t.TypedArray(.u16) {
        return call.env.typedArrayFrom(
            &[_]u16{ 0xcafe, 0xf00d, 0xc001, 0xface },
        );
    }

    pub fn generateI32(call: t.Call) !t.TypedArray(.i32) {
        const array_buffer = try call.env.arrayBuffer(32);
        const typed_array = try array_buffer.typedArray(.i32, 4, 2);

        typed_array.data[0..2].* = .{ -0x0abc0def, 0x01230456 };

        return typed_array;
    }

    pub fn generateI32Copy(call: t.Call) !t.TypedArray(.i32) {
        return call.env.typedArrayFrom(&[_]i32{ -0x0abc0def, 0x01230456 });
    }

    pub fn generateU32(call: t.Call) !t.TypedArray(.u32) {
        const array_buffer = try call.env.arrayBuffer(32);
        const typed_array = try array_buffer.typedArray(.u32, 4, 2);

        typed_array.data[0..2].* = .{ 0xcafef00d, 0xc001face };

        return typed_array;
    }

    pub fn generateU32Copy(call: t.Call) !t.TypedArray(.u32) {
        return call.env.typedArrayFrom(&[_]u32{ 0xcafef00d, 0xc001face });
    }

    pub fn generateBigI64(call: t.Call) !t.TypedArray(.i64) {
        const array_buffer = try call.env.arrayBuffer(64);
        const typed_array = try array_buffer.typedArray(.i64, 8, 2);

        typed_array.data[0..2].* = .{ -0x0abc0def01230456, 0x012304560abc0def };

        return typed_array;
    }

    pub fn generateBigI64Copy(call: t.Call) !t.TypedArray(.i64) {
        return call.env.typedArrayFrom(
            &[_]i64{ -0x0abc0def01230456, 0x012304560abc0def },
        );
    }

    pub fn generateBigU64(call: t.Call) !t.TypedArray(.u64) {
        const array_buffer = try call.env.arrayBuffer(64);
        const typed_array = try array_buffer.typedArray(.u64, 8, 2);

        typed_array.data[0..2].* = .{ 0xcafef00dc001face, 0xdadad00dfeedcede };

        return typed_array;
    }

    pub fn generateBigU64Copy(call: t.Call) !t.TypedArray(.u64) {
        return call.env.typedArrayFrom(
            &[_]u64{ 0xcafef00dc001face, 0xdadad00dfeedcede },
        );
    }

    pub fn generateF32(call: t.Call) !t.TypedArray(.f32) {
        const array_buffer = try call.env.arrayBuffer(32);
        const typed_array = try array_buffer.typedArray(.f32, 4, 2);

        typed_array.data[0..2].* = .{ -1.23456789, 1.23456789 };

        return typed_array;
    }

    pub fn generateF32Copy(call: t.Call) !t.TypedArray(.f32) {
        return call.env.typedArrayFrom(&[_]f32{ -1.23456789, 1.23456789 });
    }

    pub fn generateF64(call: t.Call) !t.TypedArray(.f64) {
        const array_buffer = try call.env.arrayBuffer(64);
        const typed_array = try array_buffer.typedArray(.f64, 8, 2);

        typed_array.data[0..2].* = .{ -1.23456789, 1.23456789 };

        return typed_array;
    }

    pub fn generateF64Copy(call: t.Call) !t.TypedArray(.f64) {
        return call.env.typedArrayFrom(&[_]f64{ -1.23456789, 1.23456789 });
    }

    pub fn getHttpBody(buf: t.ArrayBuffer) !t.TypedArray(.u8) {
        const end_of_header = "\r\n\r\n";
        const idx_eoh = std.mem.lastIndexOf(u8, buf.data, end_of_header).?;

        const idx_start_of_body = idx_eoh + end_of_header.len;
        const body_len = std.mem.indexOf(
            u8,
            buf.data[idx_start_of_body..],
            "\r\n",
        ).?;

        return buf.typedArray(.u8, idx_start_of_body, body_len);
    }

    pub fn backingArrayBuffer(call: t.Call, arr: t.TypedArray(.u16)) !t.Val {
        const sample_value = std.mem.nativeToBig(u16, arr.data[0]);

        var err_buf: [64]u8 = undefined;
        if (sample_value != 0x0405) return call.env.throwErr(.{
            .code = "AssertionFailed",
            .msg = try std.fmt.bufPrintZ(&err_buf,
                \\
                \\Expected: 0x0405
                \\Actual: 0x{x:0>4}
            , .{sample_value}),
        });

        return arr.buffer;
    }
};
