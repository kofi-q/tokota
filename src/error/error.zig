const std = @import("std");

const n = @import("../napi.zig");
const options = @import("../root.zig").options;

/// Err translations of Node-API `Status` values.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_status
pub const Err = error{
    /// A Node-API "Async Work" task was cancelled before completion.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_cancel_async_work
    AsyncWorkCancelled,

    /// Attempted `ArrayBuffer` operation or conversion on a JS `Val` of a
    /// different type.
    ArrayBufferExpected,

    /// Attempted `Array` operation or conversion on a JS `Val` of a different
    /// type.
    ArrayExpected,

    /// Attempted `BigInt` operation or conversion on a JS `Val` of a different
    /// type.
    BigIntExpected,

    /// Attempted `boolean` conversion on a JS `Val` of a different type.
    BooleanExpected,

    /// Undocumented in Node-API docs.
    CallbackScopeMismatch,

    /// Undocumented in Node-API docs.
    CannotRunJs,

    /// Attempted `Date` conversion on a JS `Val` of a different type.
    DateExpected,

    /// Attempted `ArrayBuffer.detach()` operation on a non-detachable
    /// `ArrayBuffer`.
    DetachableArrayBufferExpected,

    /// A duplicate call to `HandleScopeEscapable.escape()` was made for the
    /// save JS value.
    EscapeCalledTwice,

    ExceptionThrown,

    /// Attempted `Fn` operation or conversion on a JS `Val` of a different
    /// type.
    FunctionExpected,

    GenericFailure,
    HandleScopeMismatch,
    InvalidArg,
    NameExpected,
    NoExternalBuffersAllowed,

    /// Attempted a JS `Number` operation or conversion on a non-numeric JS
    /// `Val`.
    NumberExpected,

    /// Attempted `Object` operation or conversion on a JS `Val` of a different
    /// type.
    ObjectExpected,

    /// A JS exception has been triggered somewhere in the call stack and is
    /// pending. There are two options:
    ///
    /// - **[Recommended]** Do any necessary cleanup and return execution to JS
    /// (in the context of a Tokota callback, returning the original
    /// `PendingException` error will suffice). The exception will then be
    /// thrown in JS, where it can be handled.
    ///
    /// - Handle the exception by calling `Env.lastExceptionGetAndClear()`
    /// to essentially "`catch`" the exception and perform any necessary
    /// recovery logic. If unable to recover, the exception can be re-thrown
    /// via `Env.throw()`, or a new exception can be throws via one ot the
    /// available `throw` methods (e.g. `Env.throwErr()`, `Env.throwErrType()`).
    PendingException,

    /// Returned from [`.nonblocking`](#tokota.threadsafe.CallMode)
    /// calls to [`ThreadsafeFn.call()`](#tokota.threadsafe.FnT.call) if there
    /// is no more space in the underlying Threadsafe Function's queue.
    QueueFull,

    /// Attempted `string` conversion on a JS [`Val`](#tokota.Val) of a
    /// different type.
    StringExpected,

    /// Returned from [`ThreadsafeFn.call()`](#tokota.ThreadsafeFnT.call) if the
    /// underlying Threadsafe Function has been released, aborted, or otherwise
    /// destroyed.
    ThreadsafeFnClosing,

    /// An unknown Node-API status code was received.
    /// Details will be available via `Env.lastNapiErr()`.
    UnknownNapiError,

    /// Unused as of Node v14.5.0
    WouldDeadlock,
};

/// Triggers a JS 'FATAL ERROR' in and terminates the process.
/// This API can be called even if there is a pending JavaScript exception.
///
/// > #### ⚠ NOTE
/// > This can also be wired up as the Zig panic handler for the addon, via
/// `panicStd()`.
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn alloc() void {
///     std.heap.smp_allocator.alloc(u8, 1024) catch t.panic("OOM", null);
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_fatal_error
pub fn panic(msg: []const u8, location: ?[]const u8) noreturn {
    const loc: []const u8 = location orelse "";
    n.napi_fatal_error(loc.ptr, loc.len, msg.ptr, msg.len);
}

/// Implements the Standard Library Panic Handler interface by proxying to
/// `panic()`. Can be used in the root source file of an addon to throw Zig
/// panics as JS fatal error.
///
/// ## Example
/// ```zig
/// const std = @import("std");
/// const t = @import("tokota");
///
/// pub const panic = std.debug.FullPanic(t.panicStd);
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn alloc() void {
///     // `@panic()` now uses the wrapped `t.panicStd()`.
///     std.heap.smp_allocator.alloc(u8, 1024) catch @panic("OOM", null);
/// }
/// ```
pub fn panicStd(msg: []const u8, first_trace_addr: ?usize) noreturn {
    _ = first_trace_addr;
    panic(msg, null);
}
