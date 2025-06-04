const std = @import("std");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

const EnvData = struct {};
const env_data = EnvData{};

pub const tokota_options = t.Options{
    .napi_version = .v10,
};

comptime {
    t.exportModuleWithInit(@This(), moduleInit);
}

fn moduleInit(env: t.Env, exports: t.Val) !t.Val {
    try env.instanceDataSet(&env_data, .with(moduleDeinit));
    return exports;
}

fn moduleDeinit(_: *const EnvData, _: t.Env) !void {
    return switch (dba.deinit()) {
        .ok => {},
        .leak => t.panic("Memory leak detected", null),
    };
}

const CbOneArg = t.Fn.Typed(t.Val, t.Val);

pub fn fnCallSingleArg(cb: CbOneArg, arg: t.Val) !t.Val {
    return cb.call(arg);
}

pub fn fnCallSingleArgOptional(cb: t.Fn, arg: ?t.Val) !t.Val {
    return cb.call(arg);
}

const CbMultiArg = t.Fn.Typed(.{ t.Val, t.Val }, t.Val);

pub fn fnCallMultipleArgs(cb: CbMultiArg, arg_a: t.Val, arg_b: t.Val) !t.Val {
    return cb.call(.{ arg_a, arg_b });
}

pub fn fnCallInferredTypes(cb: t.Fn) !t.Val {
    const Object = struct { bar: u32, foo: bool };

    return cb.call(.{ true, 42, "foo", {}, Object{
        .bar = 0xf00d,
        .foo = false,
    } });
}

pub fn fnCallWithThis(this: t.Val, cb: t.Fn, a: t.Val, b: t.Val) !t.Val {
    return cb.callThis(this, .{ a, b });
}

pub fn fnCreate(call: t.Call, return_val: t.Val) !t.Fn {
    const return_val_ref = try return_val.ref(call.env, 1);

    return call.env.functionT(fnHandler, return_val_ref);
}

pub fn fnNamed(call: t.Call, name: t.TinyStr(16), return_val: t.Val) !t.Fn {
    const return_val_ref = try return_val.ref(call.env, 1);

    return call.env.functionNamedT(name.slice(), fnHandler, return_val_ref);
}

const Ref = t.Ref(t.Val);

fn fnHandler(call: t.CallT(Ref)) !?t.Val {
    const return_val_ref = try call.data() orelse return error.MissingFnData;

    defer return_val_ref.delete(call.env) catch |err| {
        call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete value reference",
        });
    };

    return return_val_ref.val(call.env);
}

pub const Closures = struct {
    const Timer = struct { start_time: i128 };
    const StopFn = t.Closure(stopTimer, *Timer);

    fn deinit(timer: *Timer, _: t.Env) !void {
        dba.allocator().destroy(timer);
    }

    pub fn startTimer() !StopFn {
        const timer = try dba.allocator().create(Timer);
        timer.* = .{ .start_time = std.time.nanoTimestamp() };

        return .init(timer, .with(deinit));
    }

    fn stopTimer(call: t.CallT(*Timer)) !i128 {
        const timer = try call.data() orelse return error.MissingFnData;
        return std.time.nanoTimestamp() - timer.start_time;
    }
};
