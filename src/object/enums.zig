//! Utilities for reading and writing enum types and values from/to JS. As enums
//! aren't natively supported in JS, the decision of how to represent native
//! enums in JS will depend on the particular use case. These cover a few
//! scenarios I've run into and may be useful in other addons.

const std = @import("std");

const Env = @import("../root.zig").Env;
const Val = @import("../root.zig").Val;

/// Options for `FromBitFlags`.
pub fn FromBitFlagsOpts(comptime PackedStruct: type) type {
    const struct_info = @typeInfo(PackedStruct).@"struct";

    if (struct_info.layout != .@"packed") @compileError(
        "expected packed struct, got " ++ @typeName(PackedStruct),
    );

    const names = std.meta.fieldNames(PackedStruct);

    const Renames = @Struct(
        .auto,
        null,
        names,
        &@splat(?[:0]const u8),
        &@splat(.{ .default_value_ptr = &@as(?[:0]const u8, null) }),
    );

    const Excludes = @Struct(
        .@"packed",
        null,
        names,
        &@splat(bool),
        &@splat(.{ .default_value_ptr = &false }),
    );

    return struct {
        /// Enum values to exclude from the converted type.
        // exclude: []const FieldEnum = &.{},
        exclude: FieldExcludes = .{},

        /// Additional enum values to include in the converted type.
        ///
        /// Useful for exposing convenient/common flag combinations.
        extra_fields: []const struct { [:0]const u8, PackedStruct } = &.{},

        /// Mapping of flag name to JS enum field name. Unspecified names will
        /// default to the original flag name.
        ///
        /// Useful to mapping to more conventional JS field names, if needed.
        // rename: std.StaticStringMap([:0]const u8) = .{},
        rename: FieldRenames = .{},

        pub const FieldExcludes = Excludes;
        pub const FieldRenames = Renames;
    };
}

/// Returns a an `enum` equivalent of the given `packed struct` bit flag type,
/// to support conversion to a JS `Object`.
///
/// This is helpful for providing flag constants in JS by exporting the
/// resulting enum type.
///
/// The following conversion rules apply:
///
/// - A `bool` field is converted to an `enum` field of the same name, with a
/// value of `1 << (field_index + padding)`, where `padding` is the sum of all
/// non-`bool` padding bits in the struct.
///
/// - Any non-`bool` fields are skipped and considered to be padding of size
/// `@bitSizeOf(@TypeOf(field))`.
///
/// ## Example
///
/// ### Zig
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// const FileModeFlags = packed struct(u8) {
///     READ: bool = false,
///     WRITE: bool = false,
///     _2: u3 = 0,
///     EXECUTE: bool = false,
///     _: u2 = 0,
/// };
///
/// /// Export an enum object of flag constants.
/// pub const FileMode = t.enums.FromBitFlags(FileModeFlags, .{});
///
/// /// Receive flag values in the original bit flags format.
/// pub fn setFlags(flags: FileModeFlags) void {
///     if (flags.WRITE or flags.EXECUTE) assertOwnership();
///     // ...
/// }
/// ```
///
/// ### JS
/// ```js
/// const assert = require("node:assert");
/// const { FileMode, setFlags } = require("./addon.node");
///
/// assert.deepEqual(FileMode, {
///   READ: 1 << 0,
///   WRITE: 1 << 1,
///   EXECUTE: 1 << 5,
/// });
///
/// setFlags(FileMode.READ | FileMode.WRITE);
/// ```
pub fn FromBitFlags(
    comptime PackedStruct: type,
    comptime opts: FromBitFlagsOpts(PackedStruct),
) type {
    const info = @typeInfo(PackedStruct).@"struct";
    const field_count_max =
        info.field_names.len + opts.extra_fields.len + 1;

    const BackingInt = info.backing_integer.?;
    comptime var names: [field_count_max][]const u8 = undefined;
    comptime var values: [field_count_max]BackingInt = undefined;
    comptime var count: usize = 0;
    comptime var bit_index: usize = 0;

    comptime for (info.field_names, info.field_types) |name, typ| {
        switch (typ) {
            bool => {
                defer bit_index += 1;

                if (@field(opts.exclude, name)) continue;

                names[count] = @field(
                    opts.rename,
                    name,
                ) orelse name;

                values[count] = 1 << bit_index;

                count += 1;
            },
            else => |Int| bit_index += @typeInfo(Int).int.bits,
        }
    };

    comptime for (opts.extra_fields) |entry| {
        names[count] = entry[0];
        values[count] = @as(BackingInt, @bitCast(entry[1]));
        count += 1;
    };

    return @Enum(
        BackingInt,
        .nonexhaustive,
        names[0..count],
        values[0..count],
    );
}

/// Wrapper type for converting Zig enum tags to/from JS string values, for
/// cases where they are more semantically appropriate/convenient than the
/// integer values.
///
/// > #### ⚠ NOTE
/// > For 1st-party enums, `StringEnumImpl` will likely be more
/// ergonomic to use. `ToStringEnum` is only necessary when working with
/// 3rd-party enums that can't be modified.
///
/// ## Example
///
/// ### Zig
/// ```zig
/// const t = @import("tokota");
/// const StateExternal = @import("external_lib").State;
///
/// const State = t.enums.ToStringEnum(StateExternal);
///
/// pub fn transition(initialState: State, input: u8) !State {
///     return switch (initialState.value) {
///         .start => switch (input) {
///             '{' => .{ .value = .object_start },
///             else => error.UnexpectedToken
///         },
///         .object_start => switch (input) {
///             '}' => .{ .value = .post_value },
///             else => error.UnexpectedToken
///         },
///         else => error.Todo,
///     };
/// }
/// ```
///
/// ### JS
/// ```js
/// const assert = require("node:assert");
/// const addon = require("./addon.node");
///
/// let state = addon.transition("start", "{");
/// assert.equal(state, "object_start")
///
/// state = addon.transition(state, "}");
/// assert.equal(state, "post_value")
/// ```
pub fn ToStringEnum(comptime E: type) type {
    const max_len: comptime_int = blk: {
        var max_len: usize = 0;
        inline for (@typeInfo(E).@"enum".field_names) |field| {
            max_len = @max(max_len, field.len);
        }

        break :blk max_len;
    };

    return struct {
        value: E,

        pub fn fromJs(env: Env, val: Val) !@This() {
            return .{ .value = std.meta.stringToEnum(
                E,
                try val.string(env, max_len),
            ) orelse return error.InvalidEnumTag };
        }

        pub fn toJs(self: @This(), env: Env) !Val {
            return env.string(@tagName(self.value));
        }
    };
}

/// Provides JS conversion mixins for converting Zig enum tags to/from JS string
/// values, for cases where they are more semantically appropriate/convenient
/// than the integer values.
///
/// ## Example
///
/// ### Zig
/// ```zig
/// const t = @import("tokota");
///
/// const Status = enum {
///     const StringEnumImpl = t.enums.StringEnumImpl(@This());
///
///     idle,
///     @"in-progress",
///     success,
///     @"unrecoverable-error",
///
///     pub const fromJs = StringEnumImpl.fromJs;
///     pub const toJs = StringEnumImpl.toJs;
/// };
///
/// const Component = enum {
///     const StringEnumImpl = t.enums.StringEnumImpl(@This());
///
///     primary,
///     secondary,
///
///     pub const fromJs = StringEnumImpl.fromJs;
///     pub const toJs = StringEnumImpl.toJs;
/// };
///
/// pub fn status(component: Component) Status {
///     return switch (component) {
///         .primary => .@"in-progress",
///         .secondary => .idle,
///     };
/// }
/// ```
///
/// ### JS
/// ```js
/// const assert = require("node:assert");
/// const addon = require("./addon.node");
///
/// const statusPrimary = addon.status("primary");
/// assert.equal(statusPrimary, "in-progress");
///
/// const statusSecondary = addon.status("secondary");
/// assert.equal(statusSecondary, "idle");
///
/// assert.throws(() => addon.status("invalid-component"), /InvalidEnumTag/);
/// ```
pub fn StringEnumImpl(comptime E: type) type {
    const max_len: comptime_int = blk: {
        var max_len: usize = 0;
        inline for (@typeInfo(E).@"enum".field_names) |field| {
            max_len = @max(max_len, field.len);
        }

        break :blk max_len;
    };

    return struct {
        pub fn fromJs(env: Env, val: Val) !E {
            return std.meta.stringToEnum(
                E,
                try val.string(env, max_len),
            ) orelse return error.InvalidEnumTag;
        }

        pub fn toJs(self: E, env: Env) !Val {
            return env.string(@tagName(self));
        }
    };
}

test FromBitFlags {
    const Status = packed struct(u8) {
        off: bool = false,
        warming_up: bool = false,
        running: bool = false,
        _3: u2 = 0,
        power_low: bool = false,
        _: u2 = 0,
    };

    //
    // With no modifications:
    //

    const StatusUnmodified = FromBitFlags(Status, .{});

    const names_unmodified = @typeInfo(StatusUnmodified).@"enum".field_names;
    const values_unmodified = @typeInfo(StatusUnmodified).@"enum".field_values;
    try std.testing.expectEqual(4, names_unmodified.len);

    try std.testing.expectEqual(1, values_unmodified[0]);
    try std.testing.expectEqualStrings("off", names_unmodified[0]);

    try std.testing.expectEqual(1 << 1, values_unmodified[1]);
    try std.testing.expectEqualStrings(
        "warming_up",
        names_unmodified[1],
    );

    try std.testing.expectEqual(1 << 2, values_unmodified[2]);
    try std.testing.expectEqualStrings("running", names_unmodified[2]);

    try std.testing.expectEqual(1 << 5, values_unmodified[3]);
    try std.testing.expectEqualStrings(
        "power_low",
        names_unmodified[3],
    );

    //
    // With renamed fields:
    //

    const StatusConstantCase = FromBitFlags(Status, .{
        .rename = .{
            .off = "OFF",
            .warming_up = "WARMING_UP",
            .running = "RUNNING",
            .power_low = "POWER_LOW",
        },
    });

    const names_const_case = @typeInfo(StatusConstantCase).@"enum".field_names;
    const values_const_case = @typeInfo(StatusConstantCase).@"enum".field_values;
    try std.testing.expectEqual(4, names_const_case.len);

    try std.testing.expectEqual(1, values_const_case[0]);
    try std.testing.expectEqualStrings("OFF", names_const_case[0]);

    try std.testing.expectEqual(1 << 1, values_const_case[1]);
    try std.testing.expectEqualStrings(
        "WARMING_UP",
        names_const_case[1],
    );

    try std.testing.expectEqual(1 << 2, values_const_case[2]);
    try std.testing.expectEqualStrings("RUNNING", names_const_case[2]);

    try std.testing.expectEqual(1 << 5, values_const_case[3]);
    try std.testing.expectEqualStrings(
        "POWER_LOW",
        names_const_case[3],
    );

    //
    // With extra fields:
    //

    const StatusExtraFields = FromBitFlags(Status, .{
        .extra_fields = &.{
            .{ "ready_for_service", .{ .off = true, .power_low = true } },
            .{ "unknown", .{} },
        },
    });

    const names_extra_fields = @typeInfo(StatusExtraFields).@"enum".field_names;
    const values_extra_fields = @typeInfo(StatusExtraFields).@"enum".field_values;
    try std.testing.expectEqual(6, names_extra_fields.len);

    try std.testing.expectEqual(1, values_extra_fields[0]);
    try std.testing.expectEqualStrings("off", names_extra_fields[0]);

    try std.testing.expectEqual(1 << 1, values_extra_fields[1]);
    try std.testing.expectEqualStrings(
        "warming_up",
        names_extra_fields[1],
    );

    try std.testing.expectEqual(1 << 2, values_extra_fields[2]);
    try std.testing.expectEqualStrings("running", names_extra_fields[2]);

    try std.testing.expectEqual(1 << 5, values_extra_fields[3]);
    try std.testing.expectEqualStrings("power_low", names_extra_fields[3]);

    try std.testing.expectEqual(
        @as(u8, @bitCast(Status{ .off = true, .power_low = true })),
        values_extra_fields[4],
    );
    try std.testing.expectEqualStrings(
        "ready_for_service",
        names_extra_fields[4],
    );

    try std.testing.expectEqual(0, values_extra_fields[5]);
    try std.testing.expectEqualStrings("unknown", names_extra_fields[5]);

    //
    // With excluded fields:
    //

    const StatusExcludeFields = FromBitFlags(Status, .{
        .exclude = .{
            .power_low = true,
            .warming_up = true,
        },
    });

    const names_filtered = @typeInfo(StatusExcludeFields).@"enum".field_names;
    const values_filtered = @typeInfo(StatusExcludeFields).@"enum".field_values;
    try std.testing.expectEqual(2, names_filtered.len);

    try std.testing.expectEqual(1, values_filtered[0]);
    try std.testing.expectEqualStrings("off", names_filtered[0]);

    try std.testing.expectEqual(1 << 2, values_filtered[1]);
    try std.testing.expectEqualStrings("running", names_filtered[1]);
}
