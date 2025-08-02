const std = @import("std");

const n = @import("tokota").napi;
const t = @import("tokota");

pub const tokota_options = t.Options{
    .napi_version = .v9,
};

comptime {
    t.exportModule(@This());
}

pub fn callFailingFunction(call: t.Call, function: t.Fn) !t.Val {
    _ = function.call(.{}) catch |err| {
        var buf_err: [128]u8 = undefined;

        if (err != t.Err.PendingException) return call.env.throwErr(.{
            .code = "UnexpectedError",
            .msg = try std.fmt.bufPrintZ(
                &buf_err,
                "Expected error {t}, got {t}\n",
                .{ t.Err.PendingException, err },
            ),
        });

        const last_err = try call.env.lastNapiErr();
        if (last_err.code != .pending_exception) return call.env.throwErr(.{
            .code = "UnexpectedNapiLastError",
            .msg = try std.fmt.bufPrintZ(
                &buf_err,
                "Expected last error status {t}, got {t}\n",
                .{ n.Status.pending_exception, last_err.code },
            ),
        });

        return call.env.lastExceptionGetAndClear();
    };

    return error.ExpectedErrorMissing;
}

pub fn genericErr(call: t.Call, msg: t.Val, code: t.Val) !t.Val {
    return call.env.err(msg, code);
}

pub fn errFromZigErrCode(call: t.Call) !t.Val {
    return call.env.err("foo", error.MadeUpError);
}

pub fn rangeErr(call: t.Call, msg: t.Val, code: t.Val) !t.Val {
    return call.env.errRange(msg, code);
}

pub fn syntaxErr(call: t.Call, msg: t.Val, code: t.Val) !t.Val {
    return call.env.errSyntax(msg, code);
}

pub fn typeErr(call: t.Call, msg: t.Val, code: t.Val) !t.Val {
    return call.env.errType(msg, code);
}

pub fn isError(call: t.Call, value: t.Val) !bool {
    return value.isError(call.env);
}

pub fn throwExistingErr(call: t.Call, err: t.Val) !void {
    return call.env.throw(err);
}

pub fn throwGenericErr(call: t.Call, msg: t.Val, code: t.Val) !void {
    return call.env.throwErr(.{
        .code = try code.string(call.env, 32),
        .msg = try msg.string(call.env, 32),
    });
}

pub fn throwRangeErr(call: t.Call, msg: t.Val, code: t.Val) !void {
    return call.env.throwErrRange(.{
        .code = try code.string(call.env, 32),
        .msg = try msg.string(call.env, 32),
    });
}

pub fn throwSyntaxErr(call: t.Call, msg: t.Val, code: t.Val) !void {
    return call.env.throwErrSyntax(.{
        .code = try code.string(call.env, 32),
        .msg = try msg.string(call.env, 32),
    });
}

pub fn throwTypeErr(call: t.Call, msg: t.Val, code: t.Val) !void {
    return call.env.throwErrType(.{
        .code = try code.string(call.env, 32),
        .msg = try msg.string(call.env, 32),
    });
}
