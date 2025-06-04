const std = @import("std");

const Class = @import("Class.zig");
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Object = @import("Object.zig");
const Property = @import("property.zig").Property;
const t = @import("../root.zig");
const Val = @import("../root.zig").Val;

/// Wraps a given struct type in a type that is exportable as a JS
/// [Class](https://mdn.io/Class). The given struct must contain at least a
/// `pub fn constructor()` method that follows the Tokota callback function
/// pattern (see below for an example). The resulting type can either be
/// returned from a native callback, or exported as part of a namespace with
/// `exportModule()`.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const allo = std.heap.smp_allocator;
/// const std = @import("std");
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub const LightSwitch = t.ClassZ("LightSwitch", struct {
///     const Self = @This();
///
///     /// A type tag is required when wrapping a native object in a JS class.
///     /// See `Object.Tag`.
///     comptime js_tag: t.Object.Tag = .{ .lower = 0xcafe, .upper = 0xf00d },
///
///     on: bool,
///
///     pub fn constructor(call: t.Call, initially_on: bool) !t.Object {
///         const this = try call.this();
///
///         const light_switch = try allo.create(Self);
///         errdefer allo.destroy(light_switch);
///
///         // In the constructor, you can set properties on and/or attach
///         // native data to the new instance for use in later method calls.
///         light_switch.* = .{ .on = initially_on };
///         _ = try this.wrap(light_switch, .with(deinit));
///
///         return this;
///     }
///
///     fn deinit(self: *Self, _: t.Env) !void {
///         allo.destroy(self);
///     }
///
///     pub fn toggle(call: t.Call) !void {
///         // Extract the previously wrapped native data instance.
///         const self = try call.thisUnwrap(*Self) orelse {
///             return error.InvalidLightSwitchInstance;
///         };
///
///         self.on = !self.on;
///     }
///
///     pub fn isOn(call: t.Call) !bool {
///         const self = try call.thisUnwrap(*Self) orelse {
///             return error.InvalidLightSwitchInstance;
///         };
///
///         return self.on;
///     }
/// });
/// ```
///
/// ```js
/// // main.js
///
/// const { LightSwitch } = require("./addon.node");
///
/// const lightSwitch = new LightSwitch(true);
/// console.log("Class instance created:", lightSwitch);
/// console.log("  Initial state:", lightSwitch.isOn());
///
/// lightSwitch.toggle();
/// console.log("  State after toggle:", lightSwitch.isOn());
/// ```
pub fn ClassZ(comptime name: []const u8, comptime T: type) type {
    const struct_info = switch (@typeInfo(T)) {
        .@"struct" => |info| info,

        else => |info| @compileError(
            std.fmt.comptimePrint("Expected struct type, got {s}", .{info}),
        ),
    };

    if (!@hasDecl(T, "constructor")) @compileError(std.fmt.comptimePrint(
        "Missing required `constructor()` method from class type `{s}`",
        .{@typeName(T)},
    ));

    return struct {
        pub fn fromJs(_: Env, _: Val) @This() {
            @compileError(
                \\`tokota.ClassZ` cannot be used as an addon callback argument.
                \\If you'd like to receive a JS `Class` argument, try using
                \\`tokota.Class` instead.
                \\
                \\(❓) You may need to build with the `-freference-trace` flag
                \\     to find the relevant source location.
            );
        }

        pub fn toJs(env: Env) !Val {
            var props: [struct_info.decls.len]Property = undefined;

            comptime var len = 0;
            inline for (struct_info.decls) |decl| {
                if (comptime std.mem.eql(u8, decl.name, "constructor")) {
                    continue;
                }

                const val = @field(T, decl.name);
                props[len] = if (isFn(@TypeOf(val)))
                    .method(decl.name, val, .{})
                else
                    .value(decl.name, try env.infer(val), .{ .static = true });

                len += 1;
            }

            return (try env.class(name, T.constructor, props[0..len])).ptr;
        }
    };
}

inline fn isFn(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"fn" => true,
        .pointer => |ptr_info| isFn(ptr_info.child),
        else => false,
    };
}
