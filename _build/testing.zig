const std = @import("std");

pub const Runtime = enum {
    bun,
    deno,
    node,
};

pub const RuntimeOptions = struct {
    args: ?[]const []const u8 = null,
    filename: ?[]const u8 = null,
};

pub fn build(b: *std.Build) void {
    const mode = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const step_check = b.step("check", "Generate compile-time diagnostics");
    const step_docs = b.step("docs", "Generate documentation");
    const step_test_all = b.step("test", "Run unit tests");
    const step_test_bun = b.step("test:api:bun", "Run Bun API tests");
    const step_test_deno = b.step("test:api:deno", "Run Deno API tests");
    const step_test_native = b.step("test:zig", "Run native unit tests");
    const step_test_node = b.step("test:api", "Run NodeJS API tests");

    const mod_base = b.dependency("base", .{
        .optimize = mode,
        .target = target,
    }).module("base");

    const dep_node_api = b.dependency("node_api", .{});

    const mod_testing = b.createModule(.{
        .optimize = mode,
        .root_source_file = b.path("testing/root.zig"),
        .target = target,
    });

    const lib_tokota_tests = b.addTest(.{
        .optimize = mode,
        .root_module = mod_check,
        .test_runner = .{ .mode = .simple, .path = b.path("test_runner.zig") },
        .target = target,
    });
    lib_tokota_tests.linker_allow_shlib_undefined = true;
    lib_tokota_tests.addIncludePath(dep_node_api.path("include"));

    const cmd_test_tokota = b.addRunArtifact(lib_tokota_tests);
    step_test_native.dependOn(&cmd_test_tokota.step);

    step_test_all.dependOn(step_test_native);

    const node_test_all = nodeTest(null);
    step_test_node.dependOn(node_test_all);
    if (b.args) |args| node_test_all.addArgs(args);

    const deno_test = denoTest(b);
    step_test_deno.dependOn(deno_test);

    inline for (Tests.dirs) |dirname| {
        const addon = b.addLibrary(.{
            .linkage = .dynamic,
            .name = dirname ++ " tests",
            .root_module = b.createModule(.{
                .imports = &.{
                    .{ .name = "testing", .module = mod_testing },
                    .{ .name = "tokota", .module = mod_tokota },
                },
                .optimize = mode,
                .root_source_file = b.path(b.pathJoin(&.{ dirname, "test.zig" })),
                .target = target,
            }),
        });
        addon.linker_allow_shlib_undefined = true;

        step_check.dependOn(&b.addLibrary(.{
            .name = "[check]" ++ dirname,
            .root_module = addon.root_module,
        }).step);

        const addon_install = b.addInstallFile(
            b.addInstallArtifact(addon, .{}).emitted_bin.?,
            b.pathJoin(&.{ "..", dirname, "test.addon.node" }),
        );

        node_test_all.step.dependOn(&addon_install.step);
        deno_test.dependOn(&addon_install.step);

        const bun_test = bunTest(b, b.pathJoin(&.{ ".", dirname, "test.mjs" }));
        bun_test.dependOn(&addon_install.step);
        step_test_bun.dependOn(bun_test);
    }
}

fn bunTest(b: *std.Build, opts: RuntimeOptions) *std.Build.Step {
    const bun_test = b.addSystemCommand(&.{
        "bun",
        "test",
        opts.filename orelse "",
    });

    bun_test.setEnvironmentVariable("RUNTIME", "bun");
    bun_test.setEnvironmentVariable(
        "TEST_RUNNER",
        b.path("testing/runner.bun.mjs").getPath(b),
    );

    return &bun_test.step;
}

fn denoTest(b: *std.Build, opts: RuntimeOptions) *std.Build.Step {
    const deno_test = b.addSystemCommand(&.{
        "deno",
        "test",
        "--allow-env",
        "--allow-ffi",
        "--allow-read",
        "--expose-gc",
        "--no-check",
        opts.filename orelse "",
    });

    deno_test.setEnvironmentVariable("RUNTIME", "deno");
    deno_test.setEnvironmentVariable(
        "TEST_RUNNER",
        b.path("testing/runner.deno.mjs").getPath(b),
    );

    return &deno_test.step;
}

fn nodeTest(b: *std.Build, opts: RuntimeOptions) *std.Build.Step {
    const node_test = b.addSystemCommand(
        &.{
            "node",
            "--experimental-addon-modules",
            "--expose-gc",
            "--disable-warning=ExperimentalWarning",
            "--test",
            opts.filename orelse "",
        },
    );
    node_test.setEnvironmentVariable("RUNTIME", "node");
    node_test.setEnvironmentVariable(
        "TEST_RUNNER",
        b.path("testing/runner.node.mjs").getPath(b),
    );

    return &node_test.step;
}
