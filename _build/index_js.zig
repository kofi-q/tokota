const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;

const nodeAbi = @import("targets.zig").nodeAbi;
const nodeCpu = @import("targets.zig").nodeCpu;
const nodeOs = @import("targets.zig").nodeOs;
const nodeTriple = @import("targets.zig").nodeTriple;
const packageName = @import("targets.zig").packageName;

pub fn generate(
    b: *std.Build,
    arena: *std.heap.ArenaAllocator,
    lib_name: []const u8,
    scoped_bin_packages: bool,
    targets: []const std.Target.Query,
) []const u8 {
    const allo = arena.allocator();

    var output = ArrayList(u8)
        .initCapacity(allo, targets.len * 256) catch
        @panic("OOM");

    const writer = output.writer(allo);

    writer.writeAll(
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
    ) catch @panic("OOM");

    for (targets) |query| {
        const target = b.resolveTargetQuery(query).result;
        writer.print(
            \\  case "{s}":
            \\    pkg = "{s}";
            \\    break;
            \\
        , .{
            nodeTriple(b, target),
            packageName(b, lib_name, scoped_bin_packages, target),
        }) catch @panic("OOM");
    }

    writer.writeAll(
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
    ) catch @panic("OOM");

    return output.items;
}
