const std = @import("std");

const t = @import("tokota");
const rt = @import("testing").runtime;

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModuleWithInit(@This(), init);
}

fn init(env: t.Env, exports: t.Val) !t.Val {
    const instance_data = try EnvData.init();
    try env.instanceDataSet(instance_data, .with(EnvData.deinit));

    const lifetimeData1 = try LifetimeData.init();
    _ = try env.addCleanup(lifetimeData1, LifetimeData.deinit);

    const versions_raw = try env.run("process.versions");
    const versions = try versions_raw.to(env, struct { deno: ?t.TinyStr(16) });

    // Deno panics:
    //   > deno(82258,0x16bc8f000) malloc: *** error for object 0x600001487fe0: pointer being freed was not allocated
    //   > deno(82258,0x16bc8f000) malloc: *** set a breakpoint in malloc_error_break to debug
    if (versions.deno) |_| std.debug.print(
        \\🚨 [SKIP] Deno: de-allocation error during async cleanup cb
        \\
    ,
        .{},
    ) else try env.addCleanupAsync(
        try LifetimeData.init(),
        LifetimeData.deinitAsync,
    );

    const num: u8 = 42;
    instance_data._cleanups_to_remove = .{
        .async_hook = try env.addCleanupAsyncRemovable(
            &num,
            failingAsyncCleanupCb,
        ),
        .sync_hook = try env.addCleanup(&num, failingCleanupCb),
    };

    return exports;
}

pub const InstanceData = struct {
    pub fn get(call: t.Call) !*EnvData {
        return try call.env.instanceData(*EnvData) orelse {
            return error.MissingInstanceData;
        };
    }

    pub fn set(call: t.Call) !void {
        const data = try call.env.instanceData(*EnvData) orelse {
            return error.MissingInstanceData;
        };

        data.num = 1996;
        data.str = "instance data";
    }
};

pub const Mem = struct {
    pub fn adjust(call: t.Call, delta_bytes: t.Int) !t.Int {
        const res = try call.env.adjustOwnedMem(delta_bytes);
        return @intCast(res);
    }
};

pub const Externals = struct {
    pub fn create(call: t.Call) !t.Val {
        const data = try NativeData.init();
        return call.env.external(data, .with(NativeData.deinit));
    }

    pub fn createOther(call: t.Call) !t.Val {
        const data = try OtherNativeData.init();
        return call.env.external(data, .with(OtherNativeData.deinit));
    }

    pub fn check(data: t.External(*NativeData)) !void {
        try std.testing.expectEqual(1957, data.ptr.foo);
        try std.testing.expectEqualStrings("big 6", data.ptr.bar);
    }

    const NativeData = struct {
        comptime js_tag: t.Object.Tag = .{ .lower = 0xcafe, .upper = 0xf00d },

        bar: []const u8,
        foo: u16,

        fn init() !*NativeData {
            const allo = dba.allocator();
            const data = try allo.create(NativeData);

            data.* = .{
                .foo = 1957,
                .bar = try allo.dupe(u8, "big 6"),
            };

            return data;
        }

        fn deinit(self: *NativeData, _: t.Env) !void {
            const allo = dba.allocator();
            allo.free(self.bar);
            allo.destroy(self);
        }
    };

    const OtherNativeData = struct {
        comptime js_tag: t.Object.Tag = .{ .lower = 0xf00d, .upper = 0xcafe },

        fn init() !*OtherNativeData {
            const allo = dba.allocator();
            return allo.create(OtherNativeData);
        }

        fn deinit(self: *OtherNativeData, _: t.Env) !void {
            dba.allocator().destroy(self);
        }
    };
};

pub fn removeFailingCleanupHooks(call: t.Call) !void {
    const instance_data = try call.env.instanceData(*EnvData) orelse {
        return error.MissingInstanceData;
    };

    const cleanups = instance_data._cleanups_to_remove.?;
    try cleanups.sync_hook.remove(call.env);
    if (cleanups.async_hook) |async_hook| try async_hook.remove();
}

fn failingCleanupCb(_: ?*const u8) !void {
    t.panic("unexpected call to de-registered cleanup fn", null);
}

fn failingAsyncCleanupCb(_: ?*const u8, _: t.CleanupAsync) !void {
    t.panic("unexpected call to de-registered cleanup fn", null);
}

const LifetimeData = struct {
    allo: std.mem.Allocator,
    item_a: []const u8,
    item_b: u32,

    fn init() !*LifetimeData {
        const allo = dba.allocator();
        const data = try allo.create(LifetimeData);
        data.* = .{
            .allo = allo,
            .item_a = try allo.dupe(u8, "test data"),
            .item_b = 1986,
        };

        return data;
    }

    fn deinit(self: *LifetimeData) !void {
        std.debug.assert(std.mem.eql(u8, self.item_a, "test data"));
        std.debug.assert(self.item_b == 1986);

        self.allo.free(self.item_a);
        self.allo.destroy(self);
    }

    fn deinitAsync(self: *LifetimeData, hook: t.CleanupAsync) !void {
        defer hook.remove() catch |err| t.panic(
            "unable to remove async cleanup hook",
            @errorName(err),
        );

        try self.deinit();
    }
};

const EnvData = struct {
    _allo: std.mem.Allocator,
    num: ?u32 = null,
    str: ?[:0]const u8 = null,
    _cleanups_to_remove: ?struct {
        async_hook: ?t.CleanupAsync = null,
        sync_hook: t.Cleanup,
    } = null,

    fn init() !*EnvData {
        const allo = dba.allocator();
        const data = try allo.create(EnvData);
        data.* = .{ ._allo = allo };

        return data;
    }

    fn deinit(self: *EnvData, _: t.Env) !void {
        std.debug.assert(self.num.? == 1996);
        std.debug.assert(std.mem.eql(u8, self.str.?, "instance data"));

        self._allo.destroy(self);

        return switch (dba.deinit()) {
            .ok => {},
            .leak => t.panic("Memory leak detected", null),
        };
    }
};
