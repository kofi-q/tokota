const std = @import("std");

const AnyPtr = @import("../root.zig").AnyPtr;
const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const Err = @import("../root.zig").Err;
const n = @import("../root.zig").napi;

const Finalizer = @This();

cb: ?n.FinalizeCb,
data: ?AnyPtrConst,
hint: ?AnyPtrConst,

pub const none = Finalizer{
    .cb = null,
    .data = null,
    .hint = null,
};

pub fn with(
    data: anytype,
    comptime cb: fn (@TypeOf(data), Env) anyerror!void,
) Finalizer {
    const Data = @TypeOf(data);

    const Wrapper = struct {
        pub fn proxy(env: Env, dat: Data, hint: ?AnyPtr) callconv(.c) void {
            _ = hint;
            @as(anyerror!void, @call(.always_inline, cb, .{
                dat, env,
            })) catch |err| switch (err) {
                Err.PendingException => {},

                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = "Error in async finalizer callback for " ++
                        @typeName(Data),
                }),
            };
        }
    };

    return .{
        .cb = @ptrCast(&Wrapper.proxy),
        .data = @ptrCast(data),
        .hint = null,
    };
}

pub fn withHinted(
    data: anytype,
    hint: anytype,
    comptime cb: fn (@TypeOf(data), @TypeOf(hint), Env) anyerror!void,
) Finalizer {
    const Data = @TypeOf(data);
    const Hint = @TypeOf(hint);

    const Wrapper = struct {
        pub fn proxy(env: Env, data_: Data, hint_: Hint) callconv(.c) void {
            @as(anyerror!void, @call(.always_inline, cb, .{
                data_, hint_, env,
            })) catch |err| switch (err) {
                Err.PendingException => {},

                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = "Error in async finalizer callback for " ++
                        @typeName(Data),
                }),
            };
        }
    };

    return .{
        .cb = @ptrCast(&Wrapper.proxy),
        .data = data,
        .hint = hint,
    };
}

pub fn Partial(comptime Data: type) type {
    return struct {
        const Self = @This();

        finalizer: Finalizer,

        pub const none = Self{ .finalizer = .none };

        pub fn with(comptime cb: fn (Data, Env) anyerror!void) Self {
            return .{ .finalizer = .with(@as(Data, undefined), cb) };
        }

        pub fn withHinted(
            hint: anytype,
            comptime cb: fn (Data, @TypeOf(hint), Env) anyerror!void,
        ) Self {
            return .{
                .finalizer = .withHinted(@as(Data, undefined), hint, cb),
            };
        }
    };
}
