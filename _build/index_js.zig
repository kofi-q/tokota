const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;

const AddonTarget = @import("targets.zig").AddonTarget;
const nodeAbi = @import("targets.zig").nodeAbi;
const nodeCpu = @import("targets.zig").nodeCpu;
const nodeOs = @import("targets.zig").nodeOs;
const nodeTriple = @import("targets.zig").nodeTriple;
const packageName = @import("targets.zig").packageName;
const Runtime = @import("targets.zig").Runtime;

pub fn generate(
    b: *std.Build,
    arena: *std.heap.ArenaAllocator,
    lib_name: []const u8,
    scoped_bin_packages: bool,
    targets: []const AddonTarget,
) error{ OutOfMemory, WriteFailed }![]const u8 {
    var output = try std.Io.Writer.Allocating.initCapacity(
        arena.allocator(),
        targets.len * 256,
    );

    try output.writer.writeAll(
        \\// [Tokota] Auto-generated.
        \\
        \\/* eslint-disable */
        \\
        \\const fs = require("node:fs");
        \\
        \\let pkg;
        \\
        \\const abi = detectAbi();
        \\const target = (abi)
        \\  ? `${process.platform}-${process.arch}-${abi}`
        \\  : `${process.platform}-${process.arch}`;
        \\
        \\switch (target) {
        \\
    );

    var win32_runtimes = std.EnumSet(Runtime).initEmpty();
    for (targets) |t| {
        const target = b.resolveTargetQuery(t.query).result;

        if (target.os.tag == .windows) {
            win32_runtimes.insert(t.win32_runtime);
        }

        try output.writer.print(
            \\  case "{s}":
            \\    pkg = "{s}";
            \\    break;
            \\
        , .{
            nodeTriple(b, target, t.win32_runtime),
            packageName(
                b,
                lib_name,
                scoped_bin_packages,
                target,
                t.win32_runtime,
            ),
        });
    }

    try output.writer.writeAll(
        \\  default:
        \\    throw new Error(`Unsupported platform: ${target}`);
        \\}
        \\
        \\try {
        \\  module.exports = require(pkg);
        \\} catch (error) {
        \\  throw new Error(
        \\    `Required addon dependency not found (${pkg}):\n${error}\n\n` +
        \\    `⚠ NOTE: If optional dependencies are disabled, you may need ` +
        \\    `to add ${pkg} as an explicit dependency.\n`
        \\  );
        \\}
        \\
        \\function detectAbi() {
        \\
    );

    if (win32_runtimes.count() > 0) {
        try output.writer.print(
            \\  if (process.platform === "{s}") {{
            \\
        , .{nodeOs(.windows)});
        if (win32_runtimes.contains(.bun)) try output.writer.writeAll(
            \\    if (process.versions.bun) return "bun";
            \\
        );
        if (win32_runtimes.contains(.deno)) try output.writer.writeAll(
            \\    if (process.versions.deno) return "deno";
            \\
        );
        if (win32_runtimes.contains(.electron)) try output.writer.writeAll(
            \\    if (process.versions.electron) return "electron";
            \\
        );
        try output.writer.writeAll(
            \\    return "node";
            \\  }
            \\
            \\
        );
    }

    try output.writer.writeAll(
        \\  if (process.platform !== "linux") return null;
        \\
        \\  try {
        \\    const lddContents = fs.readFileSync("/usr/bin/ldd", "utf8");
        \\    if (lddContents.includes("GLIBC")) return "glibc";
        \\    if (lddContents.includes("musl")) return "musl";
        \\  } catch {}
        \\
        \\  if (process.report?.getReport()?.header.glibcVersionRuntime) {
        \\    return "glibc";
        \\  }
        \\
        \\  throw new Error("Unable to detect Linux ABI");
        \\}
        \\
    );

    return output.written();
}
