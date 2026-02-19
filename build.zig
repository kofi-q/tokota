const std = @import("std");

const base = @import("base");

pub const _build = @import("_build/root.zig");
pub const Addon = _build.Addon;
pub const napi_proxy = _build.napi_proxy;
pub const node_dll = _build.node_dll;
pub const node_stub_so = _build.node_stub_so;
pub const npm = _build.npm;
pub const tokota = _build.tokota;
const targets = @import("_build/targets.zig");

pub fn build(b: *std.Build) void {
    const mode = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const win32_runtime = b.option(
        targets.Runtime,
        "win32-runtime",
        "Windows addon runtime mode: dynamic|node|electron|bun|deno",
    ) orelse .dynamic;

    const steps = Steps{
        .check = b.step("check", "Generate compiler diagnostics"),
        .docs = b.step("docs", "Generate documentation"),
        .deps_js = b.step("deps:js", "Install JS deps"),
        .fmt = b.step("fmt", "Format/lint source files"),
        .tests = b.step("test", "Run all tests"),
        .test_bun = b.step("test:bun", "Run Bun integration tests"),
        .test_ci = b.step("test:ci", "Run CI tests"),
        .test_deno = b.step("test:deno", "Run Deno integration tests"),
        .test_node = b.step("test:node", "Run NodeJS integration tests"),
        .test_win32_addons = b.step(
            "test:win32:addons",
            "Cross-compile Windows addons in dynamic and static modes",
        ),
        .test_zig = b.step("test:zig", "Run native unit tests"),
        .typecheck = b.step("typecheck", "Run JS type checks"),
        .symbols = b.step("symbols", "Generate Node-API symbol stubs"),
        .symbols_check = b.step(
            "symbols:check",
            "Fail if generated Node-API symbol stubs are out of date",
        ),
    };

    steps.check.dependOn(steps.symbols);

    steps.tests.dependOn(steps.fmt);
    steps.tests.dependOn(steps.symbols);
    steps.tests.dependOn(steps.test_bun);
    steps.tests.dependOn(steps.test_deno);
    steps.tests.dependOn(steps.test_node);
    steps.tests.dependOn(steps.test_win32_addons);
    steps.tests.dependOn(steps.test_zig);
    steps.tests.dependOn(steps.typecheck);

    steps.test_ci.dependOn(steps.fmt);
    steps.test_ci.dependOn(steps.symbols);
    steps.test_ci.dependOn(steps.symbols_check);
    steps.test_ci.dependOn(steps.test_win32_addons);
    steps.test_ci.dependOn(steps.test_zig);
    steps.test_ci.dependOn(steps.typecheck);

    const mod_tokota = b.addModule(
        "tokota",
        tokota.moduleOpts(b, mode, target),
    );

    var dep_tokota_internal = std.Build.Dependency{ .builder = b };

    b.addNamedLazyPath(node_dll.def_name, b.path(node_dll.def_path));
    b.addNamedLazyPath(napi_proxy.src_name, b.path(napi_proxy.src_path));
    b.addNamedLazyPath(node_stub_so.src_name, b.path(node_stub_so.src_path));

    steps.symbols.dependOn(&node_dll.updateSource(
        b,
        steps.check,
        mode,
        &dep_tokota_internal,
    ).step);
    steps.symbols.dependOn(&node_stub_so.updateSource(
        b,
        steps.check,
        mode,
        &dep_tokota_internal,
    ).step);
    steps.symbols.dependOn(&napi_proxy.updateSource(
        b,
        steps.check,
        mode,
        &dep_tokota_internal,
    ).step);

    const symbols_diff = b.addSystemCommand(&.{
        "git",
        "diff",
        "--exit-code",
        "--",
    });
    symbols_diff.addArgs(&.{
        node_stub_so.src_path,
        node_dll.def_path,
        napi_proxy.src_path,
    });
    symbols_diff.step.dependOn(steps.symbols);
    steps.symbols_check.dependOn(&symbols_diff.step);

    depsJs(b, &steps);
    fmt(b, &steps);
    typecheck(b, &steps);

    const mod_testing = b.createModule(.{
        .optimize = mode,
        .root_source_file = b.path("src/testing/root.zig"),
        .target = target,
    });

    const lib_check = libCheck(b, &steps, mode, target);
    checkOptions(b, &steps, mode, target);

    const lib_tokota_tests = b.addTest(.{
        .root_module = lib_check.root_module,
        .test_runner = .{ .mode = .simple, .path = b.path("test_runner.zig") },
    });
    Addon.linkNodeStub(b, lib_tokota_tests, .{
        .dep_tokota = &dep_tokota_internal,
        .win32_runtime = win32_runtime,
    });

    const cmd_test_tokota = b.addRunArtifact(lib_tokota_tests);
    steps.test_zig.dependOn(&cmd_test_tokota.step);

    inline for (examples.configs) |config| {
        const example_dir = b.pathJoin(&.{ examples.dir, config.name });

        const addon = Addon.create(b, .{
            .imports = &.{
                .{ .name = "testing", .module = mod_testing },
            },
            .link_libc = (target.result.os.tag == .linux) and config.link_libc,
            .mode = mode,
            .name = "addon",
            .output_dir = .{ .custom = b.pathJoin(&.{ "..", example_dir }) },
            .root_source_file = b.path(
                b.pathJoin(&.{ example_dir, "main.zig" }),
            ),
            .target = target,
            .tokota = .{ .dep = &dep_tokota_internal },
            .win32_runtime = win32_runtime,
        });

        const node_run = b.addSystemCommand(&.{
            "node", "--expose-gc", "main.js",
        });
        node_run.setCwd(b.path(example_dir));
        node_run.step.dependOn(&addon.install.step);

        const example_run = b.step(
            "examples:" ++ config.name,
            "Run example: '" ++ config.name ++ "'",
        );
        example_run.dependOn(&node_run.step);

        // Separate build can be useful for testing cross-compilation, e.g.:
        // zig build -Dtarget=x86_64-windows examples:add:build
        const example_build = b.step(
            "examples:" ++ config.name ++ ":build",
            "Build example: '" ++ config.name ++ "'",
        );
        example_build.dependOn(&addon.install.step);
    }

    {
        const win32_target = b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
        });

        const addon_dynamic = Addon.create(b, .{
            .mode = mode,
            .name = "test.addon.win32.dynamic",
            .output_dir = .{ .custom = "../.zig-cache/win32-addon-tests" },
            .root_source_file = b.path("examples/add/main.zig"),
            .target = win32_target,
            .tokota = .{ .dep = &dep_tokota_internal },
            .win32_runtime = .dynamic,
        });

        const addon_static = Addon.create(b, .{
            .mode = mode,
            .name = "test.addon.win32.node",
            .output_dir = .{ .custom = "../.zig-cache/win32-addon-tests" },
            .root_source_file = b.path("examples/add/main.zig"),
            .target = win32_target,
            .tokota = .{ .dep = &dep_tokota_internal },
            .win32_runtime = .node,
        });

        steps.test_win32_addons.dependOn(&addon_dynamic.install.step);
        steps.test_win32_addons.dependOn(&addon_static.install.step);
    }

    const node_test = b.addSystemCommand(&.{ "node", "--expose-gc", "--test" });
    node_test.setCwd(b.path("."));
    steps.test_node.dependOn(&node_test.step);
    if (b.args) |args| node_test.addArgs(args);

    const deno_test = denoTest(b, target.result);
    steps.test_deno.dependOn(deno_test);

    inline for (tests.configs) |config| {
        const dirpath = "src/" ++ config.dir;

        const addon = Addon.create(b, .{
            .imports = &.{
                .{ .name = "testing", .module = mod_testing },
            },
            .link_libc = (target.result.os.tag == .linux),
            .mode = mode,
            .name = "test.addon",
            .output_dir = .{ .custom = b.pathJoin(&.{ "..", dirpath }) },
            .root_source_file = b.path(b.pathJoin(&.{ dirpath, "test.zig" })),
            .target = target,
            .tokota = .{ .dep = &dep_tokota_internal },
            .win32_runtime = win32_runtime,
        });
        addon.lib.use_llvm = true;

        steps.check.dependOn(&b.addLibrary(.{
            .name = blk: {
                const name = b.dupe(config.dir);
                std.mem.replaceScalar(u8, name, '/', '-');

                break :blk b.fmt("[check] {s}", .{name});
            },
            .root_module = addon.root_module,
        }).step);

        node_test.step.dependOn(&addon.install.step);
        deno_test.dependOn(&addon.install.step);

        const bun_test = bunTest(b, b.pathJoin(&.{ ".", dirpath, "test.mjs" }));
        bun_test.dependOn(&addon.install.step);
        steps.test_bun.dependOn(bun_test);
    }

    steps.docs.dependOn(docs(b, b.addLibrary(.{
        .name = "tokota",
        .root_module = mod_tokota,
    }), "docs"));

    steps.docs.dependOn(docs(b, b.addLibrary(.{
        .name = "tokota_build",
        .root_module = b.createModule(.{
            .imports = &.{
                tokota.importBase(b, mode, target),
            },
            .optimize = mode,
            .root_source_file = b.path("_build/root.zig"),
            .target = target,
        }),
    }), "docs/build"));
}

fn bunTest(b: *std.Build, filename: []const u8) *std.Build.Step {
    const bun_test = b.addSystemCommand(&.{ "bun", "test", filename });
    bun_test.setCwd(b.path("."));

    return &bun_test.step;
}

fn checkOptions(
    b: *std.Build,
    steps: *const Steps,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) void {
    steps.check.dependOn(&b.addTest(.{
        .name = "tokota_check",
        .root_module = b.createModule(.{
            .optimize = mode,
            .root_source_file = b.path("options/root.zig"),
            .target = target,
        }),
    }).step);
}

fn denoTest(b: *std.Build, target: std.Target) *std.Build.Step {
    const deno_test = b.addSystemCommand(&.{
        "deno",
        "test",
        "--allow-env",
        "--allow-ffi",
        "--allow-read",
        "--no-check",
    });
    deno_test.setCwd(b.path("."));
    if (target.os.tag != .macos) {
        // These fail in Deno due to missing symbols.
        deno_test.addArg("--ignore=src/array_buffer/v10,src/object/v10");
    }

    return &deno_test.step;
}

fn depsJs(b: *std.Build, steps: *const Steps) void {
    const run = b.addSystemCommand(&.{ "pnpm", "i", "--frozen-lockfile" });
    steps.deps_js.dependOn(&run.step);
}

fn fmt(b: *std.Build, steps: *const Steps) void {
    const eslint = b.addSystemCommand(&.{ "pnpm", "eslint" });
    if (!isCi(b)) eslint.addArg("--fix");
    eslint.step.dependOn(steps.deps_js);

    const prettier = b.addSystemCommand(&.{ "pnpm", "prettier" });
    prettier.addArg(if (isCi(b)) "--check" else "--write");
    prettier.addArg("src");
    prettier.step.dependOn(steps.deps_js);

    const zig_fmt = b.addFmt(.{
        .check = isCi(b),
        .paths = &.{"src"},
    });

    steps.fmt.dependOn(&zig_fmt.step);
    steps.fmt.dependOn(&eslint.step);
    steps.fmt.dependOn(&prettier.step);
}

fn libCheck(
    b: *std.Build,
    steps: *const Steps,
    mode: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "tokota_check",
        .root_module = b.createModule(.{
            .imports = tokota.imports(b, mode, target),
            .link_libc = target.result.os.tag == .linux,
            .optimize = mode,
            .root_source_file = b.path("src/check.zig"),
            .target = target,
        }),
    });
    steps.check.dependOn(&lib.step);

    return lib;
}

fn typecheck(b: *std.Build, steps: *const Steps) void {
    const run = b.addSystemCommand(&.{ "pnpm", "tsc" });
    run.step.dependOn(steps.deps_js);
    steps.typecheck.dependOn(&run.step);
}

fn docs(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    out_sub_path: []const u8,
) *std.Build.Step {
    const docs_install = base.addDocs(b, lib, .{
        .html_head_extra =
        \\<link
        \\  href="https://fonts.googleapis.com/css2?family=Monoton&display=swap"
        \\  rel="stylesheet"
        \\/>
        \\<style>
        \\.tokota-logo {
        \\  font-family: "Monoton", "Roboto Mono", Menlo, Monaco, Consolas, "Courier New", monospace;
        \\  font-style: normal;
        \\  font-weight: 400;
        \\}
        \\</style>
        ,

        .html_logo =
        \\<span class="tokota-logo">tokota</span>
        ,

        .install_dir = .prefix,
        .install_subdir = out_sub_path,
        .repo_url = "https://github.com/kofi-q/tokota",
    });

    return &docs_install.step;
}

fn isCi(b: *std.Build) bool {
    return b.graph.environ_map.get("CI") != null;
}

const examples = struct {
    const Config = struct {
        name: []const u8,

        /// Linux-only setting.
        /// Spawning threads segfaults on Linux without linking libc.
        link_libc: bool = false,
    };

    const dir = "examples";

    const configs = [_]Config{
        .{ .name = "add" },
        .{ .name = "async" },
        .{ .name = "class" },
        .{ .name = "compile_errors" },
        .{ .name = "custom_arg" },
        .{ .name = "hello" },
        .{ .name = "iterator" },
        .{ .name = "stream", .link_libc = true },
    };
};

const tests = struct {
    const Config = struct {
        dir: []const u8,
    };

    const configs = [_]Config{
        .{ .dir = "." },
        .{ .dir = "array" },
        .{ .dir = "array_buffer" },
        .{ .dir = "array_buffer/v10" },
        .{ .dir = "async" },
        .{ .dir = "date" },
        .{ .dir = "error" },
        .{ .dir = "function" },
        .{ .dir = "global" },
        .{ .dir = "heap" },
        .{ .dir = "lifetime" },
        .{ .dir = "lifetime/v10" },
        .{ .dir = "number" },
        .{ .dir = "object" },
        .{ .dir = "object/v10" },
        .{ .dir = "string" },
    };
};

const Steps = struct {
    check: *std.Build.Step,
    docs: *std.Build.Step,
    deps_js: *std.Build.Step,
    fmt: *std.Build.Step,
    tests: *std.Build.Step,
    test_bun: *std.Build.Step,
    test_ci: *std.Build.Step,
    test_deno: *std.Build.Step,
    test_node: *std.Build.Step,
    test_win32_addons: *std.Build.Step,
    test_zig: *std.Build.Step,
    typecheck: *std.Build.Step,
    symbols: *std.Build.Step,
    symbols_check: *std.Build.Step,
};
