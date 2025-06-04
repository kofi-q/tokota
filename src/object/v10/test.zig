const std = @import("std");
const t = @import("tokota");

const tests = @import("test_cases.zig");

pub const tokota_options = t.Options{
    .napi_version = .v10,
};

comptime {
    t.exportModule(@This());
}

pub const Classes = tests.Classes;
pub const Objects = tests.Objects;
pub const RetroEncabulator = tests.RetroEncabulator;
pub const TurboEncabulator = tests.TurboEncabulator;

pub const ObjectsV10 = struct {
    pub fn objectWithSetterFns(call: t.Call) !t.Object {
        return call.env.objectDefine(&.{
            .method("setWithPropKey", setWithPropKey, .{}),
        });
    }

    fn setWithPropKey(call: t.Call, name: t.TinyStr(8), value: t.Val) !void {
        const this = try call.this();
        const prop_key = try call.env.propKey(name.slice());

        try this.set(prop_key, value);
    }

    pub fn getByPropKey(
        call: t.Call,
        obj: t.Object,
        name: t.TinyStr(16),
    ) !?t.Val {
        const prop_key = try call.env.propKey(name.slice());
        return obj.get(prop_key);
    }
};
