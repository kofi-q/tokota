const std = @import("std");
const tokota = @import("tokota");

const e2e_build = @import("build.e2e.zig");

pub fn build(b: *std.Build) !void {
    const mode = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const step_build_js = b.step("build:js", "Build JS lib");
    const step_clean = b.step("clean", "Clean slate - delete generated files");
    const step_e2e = b.step("e2e", "Build and publish, then run the client.");
    const step_packages = b.step("packages", "Build and emit addon packages");
    const step_publish = b.step("publish", "Build and publish addon packages");

    // Create build and publish steps for NPM packages.
    const packages = tokota.npm.createPackages(b, .{
        .mode = .ReleaseSmall,
        .npmignore = b.path(".npmignore"),
        .npmrc = b.path(".npmrc"),
        .package_json = b.path("package.json"),
        .pre_package = step_build_js,
        .root_source_file = b.path("src/root.zig"),
        .root_typings_file = b.path("lib/addon.node.d.ts"),
        .scoped_bin_packages = true,
        .strip = .{ .val = true },
        .targets = &.{
            .{ .os_tag = .linux, .cpu_arch = .aarch64, .abi = .gnu },
            .{ .os_tag = .linux, .cpu_arch = .aarch64, .abi = .musl },
            .{ .os_tag = .linux, .cpu_arch = .arm, .abi = .gnueabi },
            .{ .os_tag = .linux, .cpu_arch = .arm, .abi = .musleabi },
            .{ .os_tag = .linux, .cpu_arch = .x86_64, .abi = .gnu },
            .{ .os_tag = .linux, .cpu_arch = .x86_64, .abi = .musl },
            .{ .os_tag = .macos, .cpu_arch = .aarch64 },
            .{ .os_tag = .macos, .cpu_arch = .x86_64 },
            .{ .os_tag = .windows, .cpu_arch = .aarch64 },
            .{ .os_tag = .windows, .cpu_arch = .x86 },
            .{ .os_tag = .windows, .cpu_arch = .x86_64 },
        },
        .win32_runtimes = .{
            .bun = true,
            .electron = true,
            .node = true,
        },
    });

    step_packages.dependOn(packages.install);
    step_publish.dependOn(packages.publish);

    // Install a native-target addon binary for development.
    const dev_addon = tokota.Addon.create(b, .{
        .mode = mode,
        .output_dir = .{ .custom = "../lib" },
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    b.getInstallStep().dependOn(&dev_addon.install.step);

    //
    // Build/clean steps for the JS lib and E2E test:
    //

    const build_js = b.addSystemCommand(&.{ "pnpm", "build" });
    build_js.step.dependOn(step_clean);
    step_build_js.dependOn(&build_js.step);

    const clean_js = b.addRemoveDirTree(b.path("build"));
    step_clean.dependOn(&clean_js.step);

    const clean_publish = b.addRemoveDirTree(b.path("zig-out/publish"));
    step_clean.dependOn(&clean_publish.step);

    const e2e = e2e_build.create(b, step_publish);
    step_e2e.dependOn(e2e.client_run);
    step_clean.dependOn(e2e.registry_clean);
    step_clean.dependOn(e2e.client_clean);
}
