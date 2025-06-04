//! `Env` API methods for JS `Array` creation.

const Array = @import("Array.zig");
const Env = @import("../root.zig").Env;
const n = @import("../napi.zig");
const Val = @import("../root.zig").Val;

/// Returns a newly allocated JS `Array`. Use `Env.arrayN()` to specify an
/// initial array length.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_array
pub fn array(self: Env) !Array {
    var ptr: ?Val = null;
    try n.napi_create_array(self, &ptr).check();

    return .{ .env = self, .ptr = ptr.? };
}

/// Returns a newly allocated JS `Array` with the given elements set in order.
/// `items` must be indexable (an array, slice, or tuple). Non-`Val` elements
/// are converted to `Val` first, if supported (see `Env.infer()`).
///
/// > #### ⚠ NOTE
/// > This is not recommended for large collections, since creating
/// large numbers of JS `Val`s at a time is resource-inefficient.
/// (See https://nodejs.org/docs/latest/api/n-api.html#making-handle-lifespan-shorter-than-that-of-the-native-method)
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_array_with_length
pub fn arrayFrom(self: Env, items: anytype) !Array {
    const Items = @TypeOf(items);

    const tuple_len: ?comptime_int = switch (@typeInfo((Items))) {
        .@"struct" => |s| blk: {
            if (!s.is_tuple) @compileError("Expected indexable type.");
            break :blk s.fields.len;
        },
        .pointer => |ptr| switch (ptr.size) {
            .one => switch (@typeInfo(ptr.child)) {
                .@"struct" => |s| blk: {
                    if (!s.is_tuple) @compileError("Expected indexable type.");
                    break :blk s.fields.len;
                },
                else => null,
            },
            else => null,
        },
        else => null,
    };

    if (tuple_len) |comptime_count| {
        const arr = try self.arrayN(comptime_count);
        inline for (0..comptime_count) |i| try arr.set(i, items[i]);

        return arr;
    }

    const arr = try self.arrayN(items.len);
    for (0..items.len) |i| try arr.set(i, items[i]);

    return arr;
}

/// Returns a newly allocated JS `Array` with the given initial length. If a
/// reasonable initial length is not known, `Env.array()` can be used instead.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_create_array_with_length
pub fn arrayN(self: Env, len: usize) !Array {
    var ptr: ?Val = null;
    try n.napi_create_array_with_length(self, @intCast(len), &ptr).check();

    return .{ .env = self, .ptr = ptr.? };
}
