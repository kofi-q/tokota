const std = @import("std");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub const tokota_options = t.Options{
    .napi_version = .v10,
};

comptime {
    t.exportModule(@This());
}

pub const Latin1 = struct {
    pub fn create(call: t.Call, ptr: t.Val) !t.Val {
        const string_utf8 = try ptr.string(call.env, 16);
        return call.env.strLatin1(string_utf8);
    }

    const OwnedString = struct {
        const tag = t.Object.Tag{
            .lower = 0x13a5a1673adc44b3,
            .upper = 0xb86a38aaf4f6810b,
        };
        comptime js_tag: t.Object.Tag = tag,

        value: [:0]u8,

        fn init(value: [:0]const u8) !*OwnedString {
            const allo = dba.allocator();
            const str = try allo.create(OwnedString);
            str.* = .{ .value = try allo.dupeZ(u8, value) };

            return str;
        }

        // This is split out to enable verification that the `strLatin1Owned()`
        // finalizer is set up properly to call back with the string pointer.
        fn deinitValue(ptr: [*:0]u8, _: t.Env) !void {
            var str = std.mem.span(ptr);

            const owner: *OwnedString = @fieldParentPtr("value", &str);
            std.debug.assert(owner.js_tag == OwnedString.tag);

            dba.allocator().free(owner.value);
        }

        fn deinitOwner(self: *OwnedString, _: t.Env) !void {
            dba.allocator().destroy(self);
        }
    };

    pub fn createOwned(call: t.Call) !t.Object {
        const string_native = try OwnedString.init("foo");

        const str_js = try call.env.strLatin1Owned(
            string_native.value,
            .with(OwnedString.deinitValue),
        );

        const obj = try call.env.objectDefine(&.{
            .value("str", str_js.ptr, .{}),
            .method("updateOwnedStr", updateOwnedStr, .{}),
        });
        _ = try obj.wrap(string_native, .with(OwnedString.deinitOwner));

        return obj;
    }

    fn updateOwnedStr(call: t.Call) !void {
        const string_native = try call
            .thisUnwrap(*OwnedString) orelse return error.InvalidThis;

        string_native.value[0..3].* = "bar".*;
    }

    pub fn extractBuf(call: t.Call, ptr: t.Val) !t.Val {
        // Make room for 8 chars + sentinel byte.
        var buf: [8 + 1]u8 = undefined;
        const string_latin1 = try ptr.strLatin1Buf(call.env, &buf);

        return call.env.strLatin1(string_latin1);
    }

    pub fn extractN(call: t.Call, ptr: t.Val) !t.Val {
        const string_latin1 = try ptr.strLatin1(call.env, 8);
        return call.env.strLatin1(string_latin1);
    }

    pub fn extractAlloc(call: t.Call, ptr: t.Val) !t.Val {
        const allo = dba.allocator();
        const string_latin1 = try ptr.strLatin1Alloc(call.env, allo);
        defer allo.free(string_latin1);

        return call.env.strLatin1(string_latin1);
    }

    pub fn len(call: t.Call, ptr: t.Val) !u32 {
        const result = try ptr.strLatin1Len(call.env);
        return @intCast(result);
    }
};

pub const Utf8 = struct {
    pub fn create(call: t.Call, ptr: t.Val) !t.Val {
        const string_utf8 = try ptr.string(call.env, 16);
        return call.env.string(string_utf8);
    }

    pub fn extractBuf(call: t.Call, ptr: t.Val) !t.Val {
        // Make room for 8 chars + sentinel byte.
        var buf: [8 + 1]u8 = undefined;
        const string_utf8 = try ptr.stringBuf(call.env, &buf);

        return call.env.string(string_utf8);
    }

    pub fn extractN(call: t.Call, ptr: t.Val) !t.Val {
        const string_utf8 = try ptr.string(call.env, 8);
        return call.env.string(string_utf8);
    }

    pub fn extractAlloc(call: t.Call, ptr: t.Val) !t.Val {
        const allo = dba.allocator();
        const string_utf8 = try ptr.stringAlloc(call.env, allo);
        defer allo.free(string_utf8);

        return call.env.string(string_utf8);
    }

    pub fn len(call: t.Call, ptr: t.Val) !u32 {
        const result = try ptr.stringLen(call.env);
        return @intCast(result);
    }
};

pub const Utf16 = struct {
    pub fn create(call: t.Call, ptr: t.Val) !t.Val {
        const string_utf16 = try ptr.strUtf16(call.env, 32);
        return call.env.strUtf16(string_utf16);
    }

    const OwnedString = struct {
        const tag = t.Object.Tag{
            .lower = 0x0f9e70770f2a4111,
            .upper = 0xab2729496b2cdefc,
        };
        comptime js_tag: t.Object.Tag = tag,

        value: [:0]u16,

        fn init(value: []const u16) !*OwnedString {
            const allo = dba.allocator();
            const str = try allo.create(OwnedString);
            str.* = .{ .value = try allo.dupeZ(u16, value) };

            return str;
        }

        // This is split out to enable verification that the `strUtf16Owned()`
        // finalizer is set up properly to call back with the string pointer.
        fn deinitValue(ptr: [*:0]u16, _: t.Env) !void {
            var str = std.mem.span(ptr);

            const owner: *OwnedString = @fieldParentPtr("value", &str);
            std.debug.assert(owner.js_tag == OwnedString.tag);

            dba.allocator().free(owner.value);

            // [TODO] Find a way to run this an an env cleanup that's guaranteed
            // to run after all the strings are GC'd.
            //
            // Tried so far (neither worked on previous attempts):
            // - Schedule an `Env.cleanup()`
            // - Use `Env.instanceDataSet()` to schedule cleanup on addon unload
            return switch (dba.deinit()) {
                .ok => {},
                .leak => t.panic("Memory leak detected", null),
            };
        }

        fn deinitOwner(self: *OwnedString, _: t.Env) !void {
            dba.allocator().destroy(self);
        }
    };

    pub fn createOwned(call: t.Call) !t.Object {
        var buf: [4]u16 = undefined;
        _ = try std.unicode.utf8ToUtf16Le(&buf, "🟨🐧");

        const string_native = try OwnedString.init(&buf);

        const str_js = try call.env.strUtf16Owned(
            string_native.value,
            .with(OwnedString.deinitValue),
        );

        const obj = try call.env.objectDefine(&.{
            .value("str", str_js.ptr, .{}),
            .method("updateOwnedStr", updateOwnedStr, .{}),
        });
        _ = try obj.wrap(string_native, .with(OwnedString.deinitOwner));

        return obj;
    }

    fn updateOwnedStr(call: t.Call) !void {
        const string_native = try call
            .thisUnwrap(*OwnedString) orelse return error.InvalidThis;

        _ = try std.unicode.utf8ToUtf16Le(string_native.value[0..4], "🟩🐧");
    }

    pub fn extractBuf(call: t.Call, ptr: t.Val) !t.Val {
        // Make room for 13 chars + sentinel byte.
        var buf: [13 + 1]u16 = undefined;
        const string_utf16 = try ptr.strUtf16Buf(call.env, &buf);

        return call.env.strUtf16(string_utf16);
    }

    pub fn extractN(call: t.Call, ptr: t.Val) !t.Val {
        const string_utf16 = try ptr.strUtf16(call.env, 13);
        return call.env.strUtf16(string_utf16);
    }

    pub fn extractAlloc(call: t.Call, ptr: t.Val) !t.Val {
        const allo = dba.allocator();
        const string_utf16 = try ptr.strUtf16Alloc(call.env, allo);
        defer allo.free(string_utf16);

        return call.env.strUtf16(string_utf16);
    }

    pub fn len(call: t.Call, ptr: t.Val) !u32 {
        return @intCast(try ptr.strUtf16Len(call.env));
    }
};

pub const TinyStr = struct {
    pub fn hexToRgb(hex_color: t.TinyStr(7)) ![3]u8 {
        const hex_color_str = hex_color.slice();
        if (hex_color_str[0] != '#') return error.InvalidHexColor;

        return [_]u8{
            try std.fmt.parseInt(u8, hex_color_str[1..3], 16),
            try std.fmt.parseInt(u8, hex_color_str[3..5], 16),
            try std.fmt.parseInt(u8, hex_color_str[5..7], 16),
        };
    }
};
