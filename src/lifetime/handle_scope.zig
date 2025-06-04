const std = @import("std");

const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

pub const HandleScope = struct {
    env: Env,
    ptr: n.HandleScope,

    pub fn close(self: HandleScope) !void {
        try n.napi_close_handle_scope(self.env, self.ptr).check();
    }
};

pub const HandleScopeEscapable = struct {
    env: Env,
    ptr: n.HandleScopeEscapable,

    pub fn close(self: HandleScopeEscapable) !void {
        try n.napi_close_escapable_handle_scope(self.env, self.ptr).check();
    }

    pub fn escape(self: HandleScopeEscapable, handle: Val) !Val {
        var result: ?Val = null;
        try n.napi_escape_handle(self.env, self.ptr, handle, &result).check();

        return result.?;
    }
};
