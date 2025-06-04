const std = @import("std");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub fn init(env: t.Env, exports: t.Val) !t.Val {
    try env.instanceDataSet(try EnvData.init(), .with(EnvData.deinit));
    return exports;
}

const EnvData = struct {
    allo: std.mem.Allocator,
    temp_ref: ?t.Ref(t.Array) = null,

    pub fn init() !*EnvData {
        const allo = dba.allocator();
        const data = try allo.create(EnvData);
        data.* = .{ .allo = allo };

        return data;
    }

    pub fn deinit(self: *EnvData, _: t.Env) !void {
        defer switch (dba.deinit()) {
            .ok => {},
            .leak => t.panic("Memory leak detected", null),
        };
        dba.allocator().destroy(self);
    }

    pub fn fromEnv(env: t.Env) !*EnvData {
        return try env.instanceData(*EnvData) orelse error.InstanceDataMissing;
    }

    pub fn requireTempRef(env: t.Env) !t.Ref(t.Array) {
        const self = try fromEnv(env);
        return self.temp_ref orelse error.TempRefMissing;
    }
};

pub const Refs = struct {
    pub fn tempRefCreate(call: t.Call, val: t.Array) !void {
        const env_data = try EnvData.fromEnv(call.env);
        env_data.temp_ref = try val.ref(1);
    }

    pub fn tempRefDecrementCount(call: t.Call) !u32 {
        const temp_ref = try EnvData.requireTempRef(call.env);
        return temp_ref.unref(call.env);
    }

    pub fn tempRefDelete(call: t.Call) !void {
        const temp_ref = try EnvData.requireTempRef(call.env);
        try temp_ref.delete(call.env);
    }

    pub fn tempRefGetValue(call: t.Call) !?t.Array {
        const temp_ref = try EnvData.requireTempRef(call.env);
        return try temp_ref.val(call.env);
    }

    pub fn tempRefIncrementCount(call: t.Call) !u32 {
        const temp_ref = try EnvData.requireTempRef(call.env);
        return temp_ref.ref(call.env);
    }

    pub fn tempRefSetElement(call: t.Call, idx: u32, elem: t.Val) !void {
        const temp_ref = try EnvData.requireTempRef(call.env);
        const array = try temp_ref.val(call.env) orelse {
            return error.TempReferenceBroken;
        };

        try array.set(idx, elem);
    }

    pub fn createAndExtractRefArray(call: t.Call, val: t.Array) !?t.Array {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }

    pub fn createAndExtractRefArrayBuffer(
        call: t.Call,
        val: t.ArrayBuffer,
    ) !?t.ArrayBuffer {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }

    pub fn createAndExtractRefDataView(
        call: t.Call,
        val: t.DataView,
    ) !?t.DataView {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }

    pub fn createAndExtractRefFn(call: t.Call, val: t.Fn) !?t.Fn {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }

    pub fn createAndExtractRefObject(
        call: t.Call,
        val: t.Object,
    ) !?t.Object {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }

    pub fn createAndExtractRefPromise(
        call: t.Call,
        val: t.Promise,
    ) !?t.Promise {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }

    pub fn createAndExtractRefSymbol(
        call: t.Call,
        val: t.Symbol,
    ) !?t.Symbol {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }

    pub fn createAndExtractRefTypedArray(
        call: t.Call,
        val: t.TypedArray(.u8),
    ) !?t.TypedArray(.u8) {
        const ref = try val.ref(1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }
};

const MemUsageJs = struct { rss: u32, heapUsed: u32 };
const Result = struct { sum: f64, memUsageEnd: t.Val };

pub const HandleScopes = struct {
    pub fn sumWithHandleScopes(
        call: t.Call,
        fn_generate_num: t.Fn,
        fn_mem_usage: t.Fn,
    ) !Result {
        const env = call.env;
        var sum: f64 = 0;
        var mem_usage: MemUsageJs = undefined;

        for (0..1_000_000) |i| {
            const scope = try env.handleScope();
            defer scope.close() catch |err| call.env.throwOrPanic(.{
                .code = @errorName(err),
                .msg = "Unable to close handle scope",
            });

            const random_num_ptr = try fn_generate_num.call(.{});
            const random_num = try random_num_ptr.float64(env);
            sum += random_num;

            if (i == 1_000_000 - 1) {
                const usage = try fn_mem_usage.call(.{});
                mem_usage = try usage.object(env).to(MemUsageJs);
            }
        }

        return Result{
            .memUsageEnd = (try call.env.objectFrom(mem_usage)).ptr,
            .sum = sum,
        };
    }

    pub fn sumWithEscapableHandleScopes(
        call: t.Call,
        fn_generate_num: t.Fn,
        fn_mem_usage: t.Fn,
    ) !Result {
        var sum: f64 = 0;
        var mem_usage: t.Val = undefined;
        for (0..1_000_000) |i| {
            const scope = try call.env.handleScopeEscapable();
            defer scope.close() catch |err| call.env.throwOrPanic(.{
                .code = @errorName(err),
                .msg = "Unable to close handle scope",
            });

            const random_num_ptr = try fn_generate_num.call(.{});
            const random_num = try random_num_ptr.float64(call.env);
            sum += random_num;

            if (i == 1_000_000 - 1) {
                const mem_usage_scoped = try fn_mem_usage.call(.{});

                // Escaping the scoped handle allows the new handle to
                // outlive this inner scope and be safely referenced outside
                // of it.
                mem_usage = try scope.escape(mem_usage_scoped);
            }
        }

        return Result{
            .memUsageEnd = mem_usage,
            .sum = sum,
        };
    }
};
