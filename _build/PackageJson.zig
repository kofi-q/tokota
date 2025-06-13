//! Container for serializing/de-serializing
//! [`package.json`](https://docs.npmjs.com/cli/v11/configuring-npm/package-json)
//! files.
//!
//! This includes only the necessary subset for creating target-specific NPM
//! packages for addon binaries.

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const builtin = @import("builtin");
const ParseOptions = std.json.ParseOptions;
const std = @import("std");
const stringToEnum = std.meta.stringToEnum;
const Value = std.json.Value;

const PackageJson = @This();

name: []const u8,
type: ?Type = null,
version: Version,
description: ?[]const u8 = null,
keywords: ?[]const []const u8 = null,
author: ?[]const u8 = null,
homepage: ?[]const u8 = null,
license: ?License = null,

main: ?[]const u8 = null,
bin: ?[]const u8 = null,
files: []const []const u8 = &.{},
types: ?[]const u8 = null,

os: ?[]const []const u8 = null,
cpu: ?[]const []const u8 = null,
libc: ?[]const []const u8 = null,

dependencies: ?Dependencies = null,
devDependencies: ?Dependencies = null,
optionalDependencies: ?Dependencies = null,

engines: ?struct {
    node: []const u8,
} = null,

publishConfig: ?PublishConfig = null,

repository: ?struct {
    type: []const u8,
    url: []const u8,
} = null,

bugs: ?struct {
    url: []const u8,
} = null,

pub const Dependencies = struct {
    list: []Dependency,

    pub fn jsonParseFromValue(
        allo: Allocator,
        val: Value,
        _: ParseOptions,
    ) !Dependencies {
        if (val != .object) return error.UnexpectedToken;

        var deps = ArrayList(Dependency){};
        var entries = val.object.iterator();
        while (entries.next()) |entry| try deps.append(allo, .{
            entry.key_ptr.*,
            switch (entry.value_ptr.*) {
                .string => |version| version,
                else => return error.UnexpectedToken,
            },
        });

        return .{ .list = deps.items };
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();

        for (self.list) |kv| {
            try jws.objectField(kv[0]);
            try jws.write(kv[1]);
        }

        try jws.endObject();
    }
};

pub const Dependency = struct { []const u8, []const u8 };

pub const LibC = enum { glibc, musl };

pub const License = union(enum) {
    @"AGPL-3.0-only",
    @"Apache-2.0",
    @"BSD-2-Clause",
    @"BSD-3-Clause",
    @"BSL-1.0",
    @"CC0-1.0",
    @"CDDL-1.0",
    @"CDDL-1.1",
    @"EPL-1.0",
    @"EPL-2.0",
    @"GPL-2.0-only",
    @"GPL-3.0-only",
    ISC,
    @"LGPL-2.0-only",
    @"LGPL-2.1-only",
    @"LGPL-2.1-or-later",
    @"LGPL-3.0-only",
    @"LGPL-3.0-or-later",
    MIT,
    @"MPL-2.0",
    @"MS-PL",
    UNLICENSED,

    other: []const u8,

    const Tag = @typeInfo(License).@"union".tag_type.?;

    pub fn jsonParseFromValue(
        _: Allocator,
        val: Value,
        _: ParseOptions,
    ) !License {
        if (val != .string) return error.UnexpectedToken;

        if (stringToEnum(Tag, val.string)) |tag_value| switch (tag_value) {
            .other => {},
            inline else => |known_value| return known_value,
        };

        return .{ .other = val.string };
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.print(
            \\"{s}"
        , .{switch (self) {
            .other => |name| name,
            inline else => @tagName(self),
        }});
    }
};

pub const PublishConfig = struct {
    access: ?enum { public, restricted } = null,
    provenance: ?bool = null,
    registry: ?[]const u8 = null,
};

pub const Type = enum {
    commonjs,
    module,

    pub fn jsonParseFromValue(_: Allocator, val: Value, _: ParseOptions) !Type {
        if (val != .string) return error.UnexpectedToken;
        return stringToEnum(Type, val.string) orelse error.UnexpectedToken;
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.print(
            \\"{s}"
        , .{@tagName(self)});
    }
};

pub const Version = struct {
    sem_ver: std.SemanticVersion,

    pub fn jsonParseFromValue(
        _: Allocator,
        val: Value,
        _: ParseOptions,
    ) !Version {
        if (val != .string) return error.UnexpectedToken;

        return .{ .sem_ver = std.SemanticVersion.parse(val.string) catch {
            return error.UnexpectedToken;
        } };
    }

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.print(
            \\"{}"
        , .{self.sem_ver});
    }
};
