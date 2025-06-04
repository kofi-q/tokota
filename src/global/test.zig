const std = @import("std");

const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

pub const tokota_options = t.Options{
    .napi_version = .v9,
};

comptime {
    t.exportModule(@This());
}

pub const Symbols = struct {
    pub fn forKey(call: t.Call, key: t.TinyStr(16)) !t.Symbol {
        return call.env.symbolFor(key.slice());
    }

    pub fn new(call: t.Call, desc: t.Val) !t.Symbol {
        return call.env.symbol(desc);
    }

    pub fn newFromNative(call: t.Call) !t.Symbol {
        return call.env.symbol("✅");
    }
};
