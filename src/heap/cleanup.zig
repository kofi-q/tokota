const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");

/// A cleanup task scheduled to run when the NodeJS environment exits,
/// registered via `Env.addCleanup()`.
///
/// Can be cancelled with a call to `Cleanup.remove()`.
pub const Cleanup = struct {
    ctx: ?AnyPtrConst = null,
    cb: n.cleanup.Cb,

    pub fn Handler(comptime Ctx: type) type {
        return switch (Ctx) {
            void => fn () anyerror!void,
            else => fn (ctx: Ctx) anyerror!void,
        };
    }

    pub fn remove(self: Cleanup, env: Env) !void {
        try n.napi_remove_env_cleanup_hook(env, self.cb, self.ctx).check();
    }
};

/// An async cleanup task scheduled to run when a NodeJS environment exits,
/// registered via `Env.addCleanupAsync()`.
///
/// Can be cancelled with a call to `CleanupAsync.remove()`.
pub const CleanupAsync = struct {
    hook: n.cleanup.AsyncHook,

    pub fn Handler(comptime Ctx: type) type {
        return switch (Ctx) {
            void => fn (hook: CleanupAsync) anyerror!void,
            else => fn (ctx: Ctx, hook: CleanupAsync) anyerror!void,
        };
    }

    /// De-registers the corresponding cleanup hook. This will prevent the hook
    /// from being executed, unless it has already started executing.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_remove_async_cleanup_hook
    pub fn remove(self: CleanupAsync) !void {
        try n.napi_remove_async_cleanup_hook(self.hook).check();
    }
};
