//! `Env` API methods for creating JS string values.

const std = @import("std");

const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const requireNapiVersion = @import("../features.zig").requireNapiVersion;
const StrLatin1Owned = @import("types.zig").StrLatin1Owned;
const StrUtf16Owned = @import("types.zig").StrUtf16Owned;
const Val = @import("../root.zig").Val;

/// Creates a JS string from a UT8-encoded string. The string is copied by
/// the Node engine and can be freed, if necessary.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_string_utf8
pub fn string(self: Env, str: []const u8) !Val {
    var val: ?Val = null;
    try n.napi_create_string_utf8(self, str.ptr, str.len, &val).check();

    return val.?;
}

/// Creates a JS string from a null-terminated pointer to a  UT8-encoded string.
/// The string is copied by the Node engine and can be freed, if necessary.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_string_utf8
pub fn stringZ(self: Env, ptr: [*:0]const u8) !Val {
    const str = std.mem.span(ptr);

    var val: ?Val = null;
    try n.napi_create_string_utf8(self, str.ptr, str.len, &val).check();

    return val.?;
}

/// Creates a JS string from a ISO-8859-1-encoded string. The string is copied
/// by the Node engine and can be freed, if necessary.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_string_latin1
pub fn strLatin1(self: Env, str: []const u8) !Val {
    var val: ?Val = null;
    try n.napi_create_string_latin1(self, str.ptr, str.len, &val).check();

    return val.?;
}

/// Creates a JS string value from the given ISO-8859-1-encoded string,
/// potentially with or without copying. A finalizer callback can be specified,
/// which will be called when the JS string is garbage collected (or
/// immediately, if the native string is copied by the Node-API engine).
///
/// Caller owns the memory, which must stay valid until the finalizer is called.
///
/// https://nodejs.org/docs/latest/api/n-api.html#node_api_create_external_string_latin1
pub fn strLatin1Owned(
    self: Env,
    str: [:0]const u8,
    finalizer_partial: Finalizer.Partial([*:0]u8),
) !StrLatin1Owned {
    requireNapiVersion(.v10);

    var val: ?Val = null;
    var copied: bool = undefined;
    try n.node_api_create_external_string_latin1(
        self,
        str.ptr,
        str.len,
        finalizer_partial.finalizer.cb,
        finalizer_partial.finalizer.hint,
        &val,
        &copied,
    ).check();

    return .{ .copied = copied, .data = str, .ptr = val.? };
}

/// Creates a JS string value from a UTF16-LE-encoded string. The string is
/// copied by the Node engine and can be freed, if necessary.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_string_utf16
pub fn strUtf16(self: Env, str: []const u16) !Val {
    var val: ?Val = null;
    try n.napi_create_string_utf16(self, str.ptr, str.len, &val).check();

    return val.?;
}

/// Creates a JS string value from the given UTF16-LE-encoded string,
/// potentially with or without copying. A finalizer callback can be specified,
/// which will be called when the JS string is garbage collected (or
/// immediately, if the native string is copied by the Node-API engine).
///
/// Caller owns the memory, which must stay valid until the finalizer is called.
///
/// https://nodejs.org/docs/latest/api/n-api.html#node_api_create_external_string_utf16
pub fn strUtf16Owned(
    self: Env,
    str: [:0]const u16,
    finalizer_partial: Finalizer.Partial([*:0]u16),
) !StrUtf16Owned {
    requireNapiVersion(.v10);

    var val: ?Val = null;
    var copied: bool = undefined;
    try n.node_api_create_external_string_utf16(
        self,
        str.ptr,
        str.len,
        finalizer_partial.finalizer.cb,
        finalizer_partial.finalizer.hint,
        &val,
        &copied,
    ).check();

    return .{ .copied = copied, .data = str, .ptr = val.? };
}

/// Creates a JS string value from a null-terminated pointer to a
/// UTF16-LE-encoded string. The string is copied by the Node engine and can be
/// freed, if necessary.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_string_utf16
pub fn strUtf16Z(self: Env, ptr: [*:0]const u16) !Val {
    const str = std.mem.span(ptr);

    var val: ?Val = null;
    try n.napi_create_string_utf16(self, str.ptr, str.len, &val)
        .check();

    return val.?;
}
