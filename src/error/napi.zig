const n = @import("../napi.zig");
const t = @import("../root.zig");

/// Result codes returned from Node-API method calls.
///
/// https://nodejs.org/docs/latest/api/n-api.html#Status
pub const Status = enum(c_int) {
    ok = 0,
    invalid_arg = 1,
    object_expected = 2,
    string_expected = 3,
    name_expected = 4,
    function_expected = 5,
    number_expected = 6,
    boolean_expected = 7,
    array_expected = 8,
    generic_failure = 9,
    pending_exception = 10,
    cancelled = 11,
    escape_called_twice = 12,
    handle_scope_mismatch = 13,
    callback_scope_mismatch = 14,
    queue_full = 15,
    closing = 16,
    big_int_expected = 17,
    date_expected = 18,
    array_buffer_expected = 19,
    detachable_array_buffer_expected = 20,
    /// Unused as of Node v14.5.0
    would_deadlock = 21,
    no_external_buffers_allowed = 22,
    cannot_run_js = 23,
    _,

    /// Returns a corresponding `error` for non-success status codes.
    pub fn check(self: Status) t.Err!void {
        switch (self) {
            .array_buffer_expected => return t.Err.ArrayBufferExpected,
            .array_expected => return t.Err.ArrayExpected,
            .big_int_expected => return t.Err.BigIntExpected,
            .boolean_expected => return t.Err.BooleanExpected,
            .callback_scope_mismatch => return t.Err.CallbackScopeMismatch,
            .cancelled => return t.Err.AsyncWorkCancelled,
            .cannot_run_js => return t.Err.CannotRunJs,
            .closing => return t.Err.ThreadsafeFnClosing,
            .date_expected => return t.Err.DateExpected,
            .detachable_array_buffer_expected => return t.Err.DetachableArrayBufferExpected,
            .escape_called_twice => return t.Err.EscapeCalledTwice,
            .function_expected => return t.Err.FunctionExpected,
            .generic_failure => return t.Err.GenericFailure,
            .handle_scope_mismatch => return t.Err.HandleScopeMismatch,
            .invalid_arg => return t.Err.InvalidArg,
            .name_expected => return t.Err.NameExpected,
            .no_external_buffers_allowed => return t.Err.NoExternalBuffersAllowed,
            .number_expected => return t.Err.NumberExpected,
            .ok => {},
            .object_expected => return t.Err.ObjectExpected,
            .pending_exception => return t.Err.PendingException,
            .queue_full => return t.Err.QueueFull,
            .string_expected => return t.Err.StringExpected,
            .would_deadlock => return t.Err.WouldDeadlock,

            else => {
                t.log.err("Unknown Node-API error status code: {}\n", .{self});
                return t.Err.UnknownNapiError;
            },
        }
    }
};

pub extern fn napi_create_error(
    env: t.Env,
    code: ?t.Val,
    msg: t.Val,
    result: *?t.Val,
) n.Status;

pub extern fn napi_create_range_error(
    env: t.Env,
    code: ?t.Val,
    msg: t.Val,
    result: *?t.Val,
) n.Status;

pub extern fn napi_create_type_error(
    env: t.Env,
    code: ?t.Val,
    msg: t.Val,
    result: *?t.Val,
) n.Status;

pub extern fn napi_fatal_error(
    location: [*]const u8,
    location_len: usize,
    message: [*]const u8,
    message_len: usize,
) noreturn;

pub extern fn napi_fatal_exception(env: t.Env, err: t.Val) n.Status;

pub extern fn napi_get_and_clear_last_exception(
    env: t.Env,
    val: *?t.Val,
) n.Status;

pub extern fn napi_get_last_error_info(
    env: t.Env,
    info: *?*const t.ErrorInfo,
) n.Status;

pub extern fn napi_is_error(env: t.Env, val: t.Val, res: *bool) n.Status;

pub extern fn napi_is_exception_pending(env: t.Env, res: *bool) n.Status;

pub extern fn napi_throw_error(
    env: t.Env,
    code: ?[*:0]const u8,
    msg: [*:0]const u8,
) n.Status;

pub extern fn napi_throw_range_error(
    env: t.Env,
    code: ?[*:0]const u8,
    msg: [*:0]const u8,
) n.Status;

pub extern fn napi_throw_type_error(
    env: t.Env,
    code: ?[*:0]const u8,
    msg: [*:0]const u8,
) n.Status;

pub extern fn napi_throw(env: t.Env, err: t.Val) n.Status;

pub extern fn node_api_create_syntax_error(
    env: t.Env,
    code: ?t.Val,
    msg: t.Val,
    result: *?t.Val,
) n.Status;

pub extern fn node_api_throw_syntax_error(
    env: t.Env,
    code: ?[*:0]const u8,
    msg: [*:0]const u8,
) n.Status;
