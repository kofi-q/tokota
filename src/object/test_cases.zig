const std = @import("std");
const t = @import("tokota");

const Dba = std.heap.DebugAllocator(.{});
var dba = Dba{};

const EnvData = struct {
    ref_turbo_ctor: ?t.Ref(t.Class) = null,

    pub fn init() !*EnvData {
        return dba.allocator().create(EnvData);
    }

    pub fn deinit(self: *EnvData, env: t.Env) !void {
        if (self.ref_turbo_ctor) |turbo| {
            turbo.delete(env) catch {};
        }

        dba.allocator().destroy(self);

        return switch (dba.deinit()) {
            .ok => {},
            .leak => t.panic("Memory leak detected", null),
        };
    }
};

/// Manually defined class.
pub const TurboEncabulator = struct {
    const name = "TurboEncabulator";

    comptime js_tag: t.Object.Tag = .{
        .lower = 0xbc4e0252ea684f40,
        .upper = 0x91d59b93dfc3e8ed,
    },

    fumble_guard_enabled: bool = true,
    magneto_reluctance: f64 = 0,

    const CtorData = struct { foo: u32 };
    var ctor_data = CtorData{ .foo = 500 };

    pub fn toJs(env: t.Env) !t.Val {
        const ctor = try env.classT(name, init, &ctor_data, &.{
            .value("NAME", try env.string(name), .{ .static = true }),
            .method("manufacturer", manufacturer, .{ .static = true }),
            .method("fumbleGuardEnabled", fumbleGuardEnabled, .{}),
            .method("fumbleGuardToggle", fumbleGuardToggle, .{}),
            .method("magnetoReluctance", magnetoReluctance, .{}),
            .method("magnetoReluctanceSet", magnetoReluctanceSet, .{}),
        });

        const instance_data = try EnvData.init();
        instance_data.* = .{
            .ref_turbo_ctor = try ctor.ref(1),
        };

        try env.instanceDataSet(instance_data, .with(EnvData.deinit));

        return ctor.ptr;
    }

    fn init(call: t.CallT(*CtorData)) !t.Object {
        const data = try call.data() orelse return error.MissingData;
        std.debug.assert(data == &ctor_data);

        const encabulator = try dba.allocator().create(TurboEncabulator);
        encabulator.* = .{};

        const this_obj = try call.this();
        _ = try this_obj.wrap(encabulator, .with(deinit));

        return this_obj;
    }

    fn deinit(self: *TurboEncabulator, _: t.Env) !void {
        dba.allocator().destroy(self);
    }

    fn fumbleGuardEnabled(call: t.Call) !bool {
        const self = try unwrapSelf(call);
        return self.fumble_guard_enabled;
    }

    fn fumbleGuardToggle(call: t.Call) !void {
        const self = try unwrapSelf(call);
        self.fumble_guard_enabled = !self.fumble_guard_enabled;
    }

    fn magnetoReluctance(call: t.Call) !f64 {
        const self = try unwrapSelf(call);
        return self.magneto_reluctance;
    }

    fn magnetoReluctanceSet(call: t.Call, value: f64) !void {
        const self = try unwrapSelf(call);
        self.magneto_reluctance = value;
    }

    fn manufacturer(_: t.Call) [:0]const u8 {
        return "General Electric";
    }

    fn unwrapSelf(call: t.Call) !*TurboEncabulator {
        const this_obj = try call.this();
        const self_opt = try this_obj.unwrap(*TurboEncabulator);

        const self = self_opt orelse return error.InvalidThis;

        const instance_data = try call.env.instanceData(*EnvData);
        const ctor_ref = instance_data.?.ref_turbo_ctor.?;
        const ctor = try ctor_ref.val(call.env);

        if (!try this_obj.instanceOf(ctor.?.ptr)) return error.InvalidThis;

        return self;
    }
};

/// Auto-exported class, via `ClassZ`.
pub const RetroEncabulator = t.ClassZ("RetroEncabulator", struct {
    const Self = @This();

    comptime js_tag: t.Object.Tag = .{
        .lower = 0xe8341c6582754293,
        .upper = 0x8015849aeb2803c7,
    },

    capacitive_duractance: f64 = 0.55,

    pub fn constructor(call: t.Call) !t.Object {
        const encabulator = try dba.allocator().create(Self);
        encabulator.* = .{};

        const this = try call.this();
        _ = try this.wrap(encabulator, .with(deinit));

        return this;
    }

    fn deinit(self: *Self, _: t.Env) !void {
        dba.allocator().destroy(self);
    }

    pub fn capacitiveDuractanceGet(call: t.Call) !f64 {
        const self = try call.thisUnwrap(*Self) orelse return error.InvalidThis;
        return self.capacitive_duractance;
    }

    pub fn capacitiveDuractanceSet(call: t.Call, val: f64) !void {
        const self = try call.thisUnwrap(*Self) orelse return error.InvalidThis;
        self.capacitive_duractance = val;
    }
});

pub const Classes = struct {
    pub fn create(class: t.Class, args: t.Array) !t.Object {
        var buf_args: [2]t.Val = undefined;
        const args_len = @max(buf_args.len, try args.len());

        for (0..args_len) |i| {
            buf_args[i] = try args.get(i);
        }

        return class.new(buf_args[0..args_len]);
    }

    pub fn isTurboEncabulator(call: t.Call, object: t.Object) !bool {
        const instance_data = try call.env.instanceData(*EnvData);
        const ctor_ref = instance_data.?.ref_turbo_ctor.?;
        const class = try ctor_ref.val(call.env);

        return object.instanceOf(class.?.ptr);
    }
};

pub const Objects = struct {
    pub fn objectWithValues(call: t.Call, key: t.Val, val: t.Val) !t.Object {
        return call.env.objectDefine(&.{
            .value(key, val, .{}),
        });
    }

    pub fn objectWithData(call: t.Call, a: t.Val, b: t.Val) !t.Object {
        const allo = dba.allocator();

        const fn_data_a = try a.stringAlloc(call.env, allo);
        _ = try call.env.addCleanup(fn_data_a.ptr, deinitMethodData);

        const fn_data_b = try b.stringAlloc(call.env, allo);
        _ = try call.env.addCleanup(fn_data_b.ptr, deinitMethodData);

        const fn_name_b = try call.env.string("extractDataB");

        return call.env.objectDefine(&.{
            .methodT("extractDataA", extractData, fn_data_a.ptr, .{}),
            .methodT(fn_name_b, extractData, fn_data_b.ptr, .{}),
        });
    }

    fn extractData(call: t.CallT([*:0]u8)) !t.Val {
        const data = try call.data() orelse return error.MethodDataMissing;
        return call.env.stringZ(data);
    }

    fn deinitMethodData(data: [*:0]u8) !void {
        dba.allocator().free(std.mem.span(data));
    }

    pub fn objectWithSetterFns(call: t.Call) !t.Object {
        return call.env.objectDefine(&.{
            .method("setWithStringKey", setWithStringKey, .{}),
            .method("setWithValKey", setWithValKey, .{}),
        });
    }

    fn setWithStringKey(call: t.Call, key: t.TinyStr(8), value: t.Val) !void {
        const this = try call.this();
        try this.set(key.slice(), value);
    }

    fn setWithValKey(call: t.Call, key: t.Val, value: t.Val) !void {
        const this = try call.this();
        try this.set(key, value);
    }

    pub fn getByStringKey(obj: t.Object, key: t.TinyStr(16)) !?t.Val {
        return obj.get(key.slice());
    }

    pub fn getByValKey(object: t.Object, key: t.Val) !?t.Val {
        return object.get(key);
    }

    pub fn hasStringKey(obj: t.Object, key: t.TinyStr(16)) !bool {
        return obj.has(key.slice());
    }

    pub fn hasValKey(obj: t.Object, key: t.Val) !bool {
        return obj.has(key);
    }

    pub fn hasOwnStringKey(obj: t.Object, key: t.TinyStr(16)) !bool {
        return obj.hasOwn(key.slice());
    }

    pub fn hasOwnValKey(obj: t.Object, key: t.Val) !bool {
        return obj.hasOwn(key);
    }

    pub fn deleteByStringKey(obj: t.Object, key: t.TinyStr(16)) !bool {
        return obj.delete(key.slice());
    }

    pub fn deleteByValKey(obj: t.Object, key: t.Val) !bool {
        return obj.delete(key);
    }

    pub fn getKeys(obj: t.Object) !t.Array {
        return obj.keys();
    }

    pub fn getKeysExtended(obj: t.Object) !t.Array {
        return obj.keysExtended(.include_prototypes, .no_filter, .keep_numbers);
    }

    pub fn freezeObj(obj: t.Object) !void {
        try obj.freeze();
    }

    pub fn sealObj(obj: t.Object) !void {
        try obj.seal();
    }

    pub fn addFinalizer(object: t.Object) !void {
        const ObjSpecificData = struct {
            some_cache: [256]u8,
            ref: t.Ref(t.Object),

            fn init(obj: t.Object) !*@This() {
                const allo = dba.allocator();
                const data = try allo.create(@This());
                data.* = .{
                    .some_cache = undefined,

                    // Tie this struct's lifetime to that of the JS object.
                    .ref = try obj.addFinalizer(.with(data, deinit)),
                };

                var ref_count = try data.ref.ref(obj.env);
                std.debug.assert(ref_count == 1);

                ref_count = try data.ref.unref(obj.env);
                std.debug.assert(ref_count == 0);

                return data;
            }

            fn deinit(self: *@This(), _: t.Env) !void {
                dba.allocator().destroy(self);
            }
        };

        _ = try ObjSpecificData.init(object);
    }

    const type_tags = struct {
        const foo = t.Object.Tag{
            .lower = 0xa19d03b454a740e6,
            .upper = 0xbebbb60703352100,
        };

        const bar = t.Object.Tag{
            .lower = 0xbebbb60703352100,
            .upper = 0xa19d03b454a740e6,
        };
    };

    const WrappedObject = struct {
        comptime js_tag: t.Object.Tag = type_tags.foo,

        pi: f64,

        fn init(env: t.Env) !t.Object {
            const allo = dba.allocator();
            const new = try allo.create(WrappedObject);
            new.* = .{ .pi = 3.142 };

            const js_object = try env.api(WrappedObject, {});
            _ = try js_object.wrap(new, .with(deinit));

            try expectTag(js_object, &type_tags.foo);

            return js_object;
        }

        fn deinit(self: *WrappedObject, _: t.Env) !void {
            defer dba.allocator().destroy(self);
        }

        pub fn isWrapped(call: t.Call) !bool {
            const js_this = try call.this();
            const self = try js_this.unwrap(*WrappedObject) orelse return false;

            return self.pi == 3.142;
        }

        pub fn removeWrap(call: t.Call) !void {
            const js_this = try call.this();
            const self = try js_this.wrapGetAndRemove(*WrappedObject);

            if (self) |s| try s.deinit(call.env);
        }
    };

    pub fn withRemovableWrap(call: t.Call) !t.Object {
        return WrappedObject.init(call.env);
    }

    pub fn taggedObject(call: t.Call) !t.Object {
        const obj = try call.env.object();
        try obj.tagSet(&type_tags.foo);

        try expectTag(obj, &type_tags.foo);
        try noExpectTag(obj, &type_tags.bar);

        return obj;
    }

    pub fn isTaggedObject(obj: t.Object) !bool {
        return obj.tagCheck(&type_tags.foo);
    }

    fn expectTag(obj: t.Object, tag: *const t.Object.Tag) !void {
        if (!try obj.tagCheck(tag)) return error.MismatchedObjectTag;
    }

    fn noExpectTag(obj: t.Object, tag: *const t.Object.Tag) !void {
        if (try obj.tagCheck(tag)) return error.UnexpectedObjectTagMatch;
    }

    pub fn prototypeOf(obj: t.Object) !t.Val {
        return obj.prototype();
    }
};
