const std = @import("std");
pub const tokota = @import("tokota");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const steps = Steps{
        .check = b.step("check", "Generate compiler diagnostics"),
        .deps_js = b.step("deps:js", "Install JS deps"),
    };
    const deps = Deps{
        .napi_cpp = b.dependency("napi_cpp", .{}),
        .napi_headers = b.dependency("napi_headers", .{}),
    };

    installDepsJs(b, &steps);

    inline for (tests) |config| {
        const dirpath = "src/" ++ config.dir;
        const output_dir = std.Build.InstallDir{
            .custom = b.pathJoin(&.{ "..", dirpath }),
        };

        const c = createAddonC(
            b,
            &deps,
            target,
            b.path(b.pathJoin(&.{ dirpath, "addon.c" })),
            output_dir,
        );
        const cpp = createAddonCpp(
            b,
            &deps,
            target,
            b.path(b.pathJoin(&.{ dirpath, "addon.cpp" })),
            output_dir,
        );
        const zig = createAddonZig(
            b,
            &steps,
            target,
            b.path(b.pathJoin(&.{ dirpath, "addon.zig" })),
            "addon.zig",
            output_dir,
        );
        const zig_ffi = createAddonZig(
            b,
            &steps,
            target,
            b.path(b.pathJoin(&.{ dirpath, "addon.ffi.zig" })),
            "addon.zig.ffi",
            output_dir,
        );

        b.getInstallStep().dependOn(c);
        b.getInstallStep().dependOn(cpp);
        b.getInstallStep().dependOn(&zig.install.step);
        b.getInstallStep().dependOn(&zig_ffi.install.step);

        const run = b.addSystemCommand(&.{"node"});
        run.addFileArg(b.path(b.pathJoin(&.{ dirpath, "main.js" })));
        run.step.dependOn(steps.deps_js);
        run.step.dependOn(c);
        run.step.dependOn(cpp);
        run.step.dependOn(&zig.install.step);
        run.step.dependOn(&zig_ffi.install.step);

        const bench = b.step(
            "bench:" ++ config.dir,
            "Run" ++ config.dir ++ "benchmark test",
        );
        bench.dependOn(&run.step);
    }
}

fn createAddonC(
    b: *std.Build,
    deps: *const Deps,
    target: std.Build.ResolvedTarget,
    root_file: std.Build.LazyPath,
    output_dir: std.Build.InstallDir,
) *std.Build.Step {
    const lib = b.addLibrary(.{
        .name = "hello",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .link_libc = true,
            .optimize = .ReleaseFast,
            .strip = true,
            .target = target,
        }),
    });

    lib.addCSourceFile(.{ .file = root_file });
    lib.linker_allow_shlib_undefined = true;
    lib.addIncludePath(deps.napi_headers.path("include"));
    lib.root_module.addCMacro("NAPI_VERSION", "8");

    const install = b.addInstallFileWithDir(
        b.addInstallArtifact(lib, .{}).emitted_bin.?,
        output_dir,
        "addon.c.node",
    );

    return &install.step;
}

fn createAddonCpp(
    b: *std.Build,
    deps: *const Deps,
    target: std.Build.ResolvedTarget,
    root_file: std.Build.LazyPath,
    output_dir: std.Build.InstallDir,
) *std.Build.Step {
    const lib = b.addLibrary(.{
        .name = "hello",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .link_libc = true,
            .link_libcpp = true,
            .optimize = .ReleaseFast,
            .strip = true,
            .target = target,
        }),
    });

    lib.addCSourceFile(.{ .file = root_file });
    lib.linker_allow_shlib_undefined = true;
    lib.addIncludePath(deps.napi_headers.path("include"));
    lib.addIncludePath(deps.napi_cpp.path("."));
    lib.root_module.addCMacro("NAPI_VERSION", "8");

    const install = b.addInstallFileWithDir(
        b.addInstallArtifact(lib, .{}).emitted_bin.?,
        output_dir,
        "addon.cpp.node",
    );

    return &install.step;
}

fn createAddonZig(
    b: *std.Build,
    steps: *const Steps,
    target: std.Build.ResolvedTarget,
    root_file: std.Build.LazyPath,
    name: []const u8,
    output_dir: std.Build.InstallDir,
) tokota.Addon {
    const addon = tokota.Addon.create(b, .{
        .name = name,
        .mode = .ReleaseFast,
        .output_dir = output_dir,
        .root_source_file = root_file,
        .strip = true,
        .target = target,
    });
    steps.check.dependOn(
        &b.addTest(.{ .root_module = addon.root_module }).step,
    );

    return addon;
}

fn installDepsJs(b: *std.Build, steps: *const Steps) void {
    const run = b.addSystemCommand(&.{ "pnpm", "i", "--frozen-lockfile" });
    steps.deps_js.dependOn(&run.step);
}

fn isCi() bool {
    return std.process.hasNonEmptyEnvVarConstant("CI");
}

const TestConfig = struct {
    dir: []const u8,

    /// Linux-only setting.
    /// Spawning threads segfaults on Linux without linking libc.
    link_libc: bool = false,
};
const tests = [_]TestConfig{
    .{ .dir = "add" },
    .{ .dir = "hello" },
};

const Deps = struct {
    napi_cpp: *std.Build.Dependency,
    napi_headers: *std.Build.Dependency,
};

const Steps = struct {
    check: *std.Build.Step,
    deps_js: *std.Build.Step,
};
