const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const Val = @import("../root.zig").Val;

/// A wrapper type that converts to a JS method interface object, with
/// native data bound to each exported method. The bound data can later be
/// extracted from incoming method calls via `CallT.data()`.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const std = @import("std");
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// /// Return a `tokota.Api` from an exported function to bind native data and
/// /// optionally register a finalizer to clean up one the JS object is GC'd.
/// pub fn newApi() !PuppyApi {
///     const method_data = try Shelter.init(std.heap.smp_allocator);
///     return PuppyApi.init(method_data, .with(Shelter.deinit));
/// }
///
/// /// Public decls are exported to JS, similar to `tokota.exportModule()`.
/// /// Methods can receive a `tokota.CallT` with the bound native data.
/// const PuppyApi = t.Api(*Shelter, struct {
///     const Call = t.CallT(*Shelter);
///
///     pub fn addPup(call: Call, name: t.TinyStr(16)) !void {
///         const shelter = try call.data() orelse return error.MissingData;
///
///         if (shelter.num_pups >= Shelter.capacity) return error.NoSpaceLeft;
///         defer shelter.num_pups += 1;
///
///         const allo = shelter.allo;
///         shelter.pups[shelter.num_pups] = try allo.dupe(u8, name.slice);
///     }
///
///     pub fn pupNames(call: Call) ![]const []const u8 {
///         const shelter = try call.data() orelse return error.MissingData;
///         return shelter.pups[0..shelter.num_pups];
///     }
/// });
///
/// const Shelter = struct {
///     const capacity = 42;
///
///     allo: std.mem.Allocator,
///     pups: [capacity][]const u8 = undefined,
///     num_pups: usize = 0,
///
///     fn init(allo: std.mem.Allocator) !*Shelter {
///         const shelter = try allo.create(Shelter);
///         shelter.* = .{ .allo = allo };
///
///         return shelter;
///     }
///
///     fn deinit(self: *Shelter, _: t.Env) !void {
///         const allo = self.allo;
///         for (self.pups[0..self.num_pups]) |name| allo.free(name);
///         allo.destroy(self);
///     }
/// };
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const addon = require("./addon.node");
///
/// const puppyApi = addon.newApi();
/// puppyApi.addPup("Pawrice");
/// puppyApi.addPup("Billie The Goat");
///
/// assert.deepEqual(puppyApi.pupNames(), ["Pawrice", "Billie The Goat"]);
/// ```
pub fn Api(comptime MethodData: type, comptime T: type) type {
    return struct {
        data: MethodData,
        finalizer: ?Finalizer = null,

        pub fn init(
            data: MethodData,
            finalizer: Finalizer.Partial(MethodData),
        ) @This() {
            return .{ .data = data, .finalizer = .{
                .cb = finalizer.finalizer.cb,
                .data = data,
                .hint = finalizer.finalizer.hint,
            } };
        }

        pub fn toJs(self: @This(), env: Env) !Val {
            const api = try env.api(T, self.data);
            _ = if (self.finalizer) |fin| try api.addFinalizer(fin);

            return api.ptr;
        }
    };
}
