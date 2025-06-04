const allo = std.heap.smp_allocator;
const std = @import("std");
const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

/// Exporting a struct as a `ClassZ` enables built-in conversion to a JS class.
pub const LightSwitch = t.ClassZ("LightSwitch", struct {
    const Self = @This();

    on: bool,

    /// A type tag is required when wrapping a native object in a JS class.
    ///
    /// This provides improved safety when casting pointers extracted from class
    /// method calls.
    ///
    /// The following command will generate a globally unique tag, if needed:
    /// ```sh
    /// uuidgen | sed -r -e 's/-//g' -e 's/(.{16})(.*)/.{ .lower = 0x\L\1, .upper = 0x\L\2, }/'
    /// ```
    comptime js_tag: t.Object.Tag = .{
        .lower = 0x8d2ca81d7ca840cf,
        .upper = 0xa41c6f6fa2b0aa85,
    },

    /// The required `constructor` method is invoked by the Node-API engine when
    /// a new class instance is created in JS.
    pub fn constructor(call: t.Call, initially_on: bool) !t.Object {
        const this = try call.this();

        const light_switch = try allo.create(Self);
        errdefer allo.destroy(light_switch);

        // In the constructor, you can set properties on and/or attach
        // native data to the new instance for use in later method calls.
        light_switch.* = .{ .on = initially_on };
        _ = try this.wrap(light_switch, .with(deinit));

        return this;
    }

    fn deinit(self: *Self, _: t.Env) !void {
        allo.destroy(self);
    }

    pub fn isOn(call: t.Call) !bool {
        const self = try requireSelf(call);
        return self.on;
    }

    pub fn toggle(call: t.Call) !void {
        const self = try requireSelf(call);
        self.on = !self.on;
    }

    /// Extracts the previously wrapped native instance from the JS call.
    fn requireSelf(call: t.Call) !*Self {
        return try call.thisUnwrap(*Self) orelse {
            return error.InvalidLightSwitchInstance;
        };
    }
});
