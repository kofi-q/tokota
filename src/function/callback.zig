const std = @import("std");

const Call = @import("call.zig").Call;
const CallT = @import("call.zig").CallT;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Err = @import("../root.zig").Err;
const Val = @import("../root.zig").Val;

pub const CbOptions = struct {
    DataType: type = void,
};

/// Creates a Node-API Callback wrapper around the given function, providing
/// arguments extracted and converted automatically from the JS argument values.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_callback
pub fn napiCb(comptime impl: anytype, comptime opts: CbOptions) n.Callback {
    const Impl = comptime switch (@TypeOf(impl)) {
        n.Callback => return impl,
        else => |T| T,
    };

    const msg_type_err = "Expected `fn` type, got `" ++ @typeName(Impl) ++ "`";
    const fn_info = comptime switch (@typeInfo(Impl)) {
        .@"fn" => |fn_info| fn_info,
        .pointer => |ptr_info| switch (@typeInfo(ptr_info.child)) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError(msg_type_err),
        },
        else => @compileError(msg_type_err),
    };

    const CallResolved = switch (opts.DataType) {
        void => Call,
        else => |T| CallT(T),
    };

    const idx_args_start = comptime switch (fn_info.params.len) {
        0 => 0,
        else => switch (fn_info.params[0].type.?) {
            CallResolved => 1,
            else => 0,
        },
    };

    const arg_types = comptime blk: {
        const arg_count = fn_info.params.len;
        var arg_types: [arg_count - idx_args_start]type = undefined;

        for (fn_info.params[idx_args_start..], &arg_types) |param, *arg_type| {
            arg_type.* = param.type.?;
        }

        break :blk arg_types;
    };

    const Result = comptime switch (@typeInfo(fn_info.return_type.?)) {
        .error_union => |error_union| anyerror!error_union.payload,
        else => anyerror!fn_info.return_type.?,
    };

    return struct {
        pub fn proxy(env: Env, info: n.CallInfo) callconv(.C) ?Val {
            var buf_err: [128]u8 = undefined;

            const call = CallResolved{ .env = env, .info = info };
            const args = call.argsAs(arg_types) catch |err| {
                switch (err) {
                    Err.PendingException => {},

                    else => env.throwOrPanic(.{
                        .code = @errorName(err),
                        .msg = std.fmt.bufPrintZ(
                            &buf_err,
                            "[ {s} ] JS argument conversion failed",
                            .{@errorName(err)},
                        ) catch buf_err ++ "...(truncated)",
                    }),
                }

                return null;
            };

            const result: Result = switch (idx_args_start) {
                0 => @call(.always_inline, impl, args),
                1 => @call(.always_inline, impl, .{call} ++ args),
                else => unreachable,
            };

            const payload = result catch |err| {
                switch (err) {
                    Err.PendingException => {},

                    else => env.throwOrPanic(.{
                        .code = @errorName(err),
                        .msg = std.fmt.bufPrintZ(
                            &buf_err,
                            "[ {s} ] - Error in native function",
                            .{@errorName(err)},
                        ) catch buf_err ++ "...(truncated)",
                    }),
                }

                return null;
            };

            return env.infer(payload) catch |err| {
                switch (err) {
                    Err.PendingException => {},

                    else => env.throwOrPanic(.{
                        .code = "ReturnValueConversionFailed",
                        .msg = std.fmt.bufPrintZ(
                            &buf_err,
                            "[ {s} ] JS return value conversion failed",
                            .{@errorName(err)},
                        ) catch buf_err ++ "...(truncated)",
                    }),
                }

                return null;
            };
        }
    }.proxy;
}
