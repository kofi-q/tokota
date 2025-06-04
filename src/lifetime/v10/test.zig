const std = @import("std");
const t = @import("tokota");

const tests = @import("test_cases.zig");

pub const tokota_options = t.Options{
    // Works with `v10`, but Bun requires `.experimental` at the moment:
    .napi_version = .experimental,
};

comptime {
    t.exportModuleWithInit(@This(), tests.init);
}

pub const HandleScopes = tests.HandleScopes;
pub const Refs = tests.Refs;

pub const RefsV10 = struct {
    pub fn createAndExtractRefVal(call: t.Call, val: t.Val) !?t.Val {
        const ref = try val.ref(call.env, 1);
        defer ref.delete(call.env) catch |err| call.env.throwOrPanic(.{
            .code = @errorName(err),
            .msg = "Unable to delete ref",
        });

        return ref.val(call.env);
    }
};
