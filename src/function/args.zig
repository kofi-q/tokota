const std = @import("std");
const builtin = @import("builtin");

const AnyPtrConst = @import("../root.zig").AnyPtrConst;
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Fn = @import("Fn.zig");
const napiCb = @import("callback.zig").napiCb;
const Val = @import("../root.zig").Val;

pub fn ArgOrArgsTuple(comptime types: anytype) type {
    if (@TypeOf(types) == type) return types;

    if (!isKnownLengthIndexable(types)) @compileError(
        \\Expected a single type or a tuple/array/slice of type values.
    );

    return @Tuple(&types);
}

pub fn ArgsTuple(comptime types: anytype) type {
    if (!isKnownLengthIndexable(types)) @compileError(
        \\Expected a tuple/array/slice of type values.
    );

    return @Tuple(&types);
}

pub inline fn argValues(self: Env, args: anytype) ![]const Val {
    return switch (@TypeOf(args)) {
        []Val,
        []const Val,
        => args,

        Val => &.{args},
        ?Val => &.{try self.orUndefined(args)},

        else => |T| switch (comptime @typeInfo(T)) {
            .pointer => |ptr_info| switch (@typeInfo(ptr_info.child)) {
                .@"struct" => |struct_info| if (comptime struct_info.is_tuple)
                    argTupleValues(self, args, struct_info)
                else
                    &.{try self.infer(args)},

                else => &.{try self.infer(args)},
            },

            .@"struct" => |struct_info| if (comptime struct_info.is_tuple)
                argTupleValues(self, args, struct_info)
            else
                &.{try self.infer(args)},

            else => &.{try self.infer(args)},
        },
    };
}

pub inline fn argTupleValues(
    self: Env,
    args: anytype,
    struct_info: std.builtin.Type.Struct,
) ![]const Val {
    if (!struct_info.is_tuple) @compileError("Tuple struct expected");

    const len = struct_info.fields.len;
    var values: [len]Val = undefined;

    inline for (struct_info.fields, 0..) |field, i| {
        values[i] = try self.infer(@field(args, field.name));
    }

    return values[0..];
}

pub inline fn isKnownLengthIndexable(comptime x: anytype) bool {
    return switch (@typeInfo((@TypeOf(x)))) {
        .@"struct" => |info| info.is_tuple,
        .array => true,
        .pointer => |p| p.size == .slice,
        else => false,
    };
}
