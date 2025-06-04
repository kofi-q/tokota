const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const Val = @import("../root.zig").Val;

/// Convenience type for returning data-bound callback functions to JS. The
/// given function can optionally accept a `CallT(Data)` as its first argument.
///
/// If a `finalizer` is specified, it will be called when the corresponding JS
/// function is garbage collected.
///
/// ## Example
/// #### Zig
/// ```zig
/// //! addon.zig
///
/// const std = @import("std");
/// const t = @import("tokota");
///
/// const allo = std.heap.smp_allocator;
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// const Timer = struct { start_time: i128 };
///
/// pub fn startTimer() !StopFn {
///     const timer = try allo.create(Timer);
///     timer.* = .{ .start_time = std.time.nanoTimestamp() };
///
///     return .init(timer, .with(deinitTimer));
/// }
///
/// const StopFn = t.Closure(stopTimer, *Timer);
///
/// fn stopTimer(call: t.CallT(*Timer)) !i128 {
///     const timer = try call.data() orelse return error.MissingFnData;
///     return std.time.nanoTimestamp() - timer.start_time;
/// }
///
/// fn deinitTimer(timer: *Timer, _: t.Env) !void {
///     allo.destroy(timer);
/// }
/// ```
///
/// #### JS
/// ```js
/// // main.js
///
/// const addon = require("./addon.node");
///
/// const stopTimer = addon.startTimer();
/// console.log("tick tock...");
///
/// const elapsed = stopTimer();
/// console.log("elapsed:", elapsed);
/// ```
pub fn Closure(comptime func: anytype, comptime Data: type) type {
    return struct {
        data: Data,
        finalizer: ?Finalizer = null,

        pub fn init(data: Data, finalizer: Finalizer.Partial(Data)) @This() {
            return .{ .data = data, .finalizer = .{
                .cb = finalizer.finalizer.cb,
                .data = data,
                .hint = finalizer.finalizer.hint,
            } };
        }

        pub fn fromJs(_: Env, _: Val) @This() {
            @compileError(
                \\`tokota.Closure` cannot be used as an addon callback argument.
                \\If you'd like to receive a JS function argument, try using
                \\`tokota.Fn` instead.
                \\
                \\(❓) You may need to build with the `-freference-trace` flag
                \\     to find the relevant source location.
            );
        }

        pub fn toJs(self: @This(), env: Env) !Val {
            const js_fn = try env.functionT(func, self.data);
            _ = if (self.finalizer) |fin| try js_fn.addFinalizer(fin);

            return js_fn.ptr;
        }
    };
}
