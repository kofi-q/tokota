//! Node-API addon build utilities for generating Node-compatible shared library
//! binaries from a root source file.

const ArrayList = std.ArrayListUnmanaged;
const json = std.json;
const std = @import("std");

const base = @import("base");

const Addon = @import("Addon.zig");
const AddonTarget = @import("targets.zig").AddonTarget;
const index_js = @import("index_js.zig");
const node_dll = @import("windows/node_dll.zig");
const nodeAbi = @import("targets.zig").nodeAbi;
const nodeCpu = @import("targets.zig").nodeCpu;
const nodeOs = @import("targets.zig").nodeOs;
const packageName = @import("targets.zig").packageName;
const Runtime = @import("targets.zig").Runtime;

pub const PackageJson = @import("PackageJson.zig");

/// Creates NPM packages, in the specified output directory:
///
/// - A binary NPM package for each target in `Options.targets`, containing a
///   target-specific `package.json` and `.node` addon. The `package.json` is
///   derived from the given `Options.package_json`.
///
/// - A main NPM package containing `Options.package_json` and any referenced
///   files, as well as an importer module for importing the appropriate
///   addon package for the native target at runtime. For each configured
///   target, an entry will be added to the `optionalDependencies` field of the
///   main package's `package.json`.
///
/// ## Example
///
/// ### Inputs:
/// ```txt
///  project
///    ├─ lib
///    │   ├─ addon.node.d.ts
///    │   ├─ index.d.ts
///    │   └─ index.js
///    ├─ src
///    │   └─ root.zig
///    ├─ build.zig
///    ├─ LICENSE
///    ├─ package.json
///    └─ README.md
/// ```
///
/// **build.zig:**
/// ```zig
/// const tokota = @import("tokota");
///
/// pub fn build(b: *std.Build) !void {
///     const packages = tokota.npm.package(b, .{
///        .mode = .ReleaseSmall,
///        .package_json = b.path("package.json"),
///        .root_source_file = b.path("src/root.zig"),
///        .root_typings_file = b.path("lib/addon.node.d.ts"),
///        .scoped_bin_packages = true,
///        .targets = &.{
///            .{ .os_tag = .linux, .cpu_arch = .x86_64, .abi = .gnu },
///            .{ .os_tag = .macos, .cpu_arch = .aarch64 },
///            .{ .os_tag = .windows, .cpu_arch = .x86_64 },
///        },
///        .win32_runtimes = .{
///            .bun = true,
///            .node = true,
///        },
///    });
/// }
/// ```
///
/// **package.json:**
/// ```json
/// {
///   "name": "my-addon",
///   "main": "lib/index.js",
///   "types": "lib/index.d.ts",
///   "files": [
///     "lib",
///     "LICENSE"
///     "README.md"
///   ]
/// }
/// ```
///
/// ### Outputs:
/// ```txt
///  project/
///    ├─ ...
///    └─ zig-out/
///        ├─ @my-addon/
///        │   ├─ macos-aarch64/
///        │   │   ├─ addon.node
///        │   │   └─ package.json
///        │   ├─ linux-x86_64-gnu/
///        │   │   ├─ addon.node
///        │   │   └─ package.json
///        │   ├─ windows-x86_64-bun/
///        │   │   ├─ addon.node
///        │   │   └─ package.json
///        │   └─ windows-x86_64-node/
///        │       ├─ addon.node
///        │       └─ package.json
///        └─ my-addon/
///            ├─ lib/
///            │   ├─ index.d.ts
///            │   ├─ index.js
///            │   ├─ addon.node.d.ts
///            │   └─ addon.node.js
///            ├─ LICENSE
///            ├─ package.json
///            └─ README.md
/// ```
///
/// **zig-out/my-addon/package.json:**
/// ```json
/// {
///   "name": "my-addon",
///   "main": "lib/index.js",
///   "types": "lib/index.d.ts",
///   "files": [
///     "lib",
///     "LICENSE"
///     "README.md"
///   ],
///   "optionalDependencies": [
///     "@my-addon/macos-aarch64",
///     "@my-addon/linux-x86_64-gnu",
///     "@my-addon/windows-x86_64-bun",
///     "@my-addon/windows-x86_64-node"
///   ]
/// }
/// ```
pub fn createPackages(b: *std.Build, opts: Options) Packages {
    var arena = std.heap.ArenaAllocator.init(b.allocator);
    defer arena.deinit();

    const allo_arena = arena.allocator();

    var bin_pkgs = ArrayList(BinPackage).initCapacity(
        allo_arena,
        opts.targets.len,
    ) catch @panic("OOM");

    const main_pkg_json, const pkg_json_opts = blk: {
        const raw, const parsed = parsePackageJson(
            b,
            &arena,
            opts.package_json,
        );
        const pkg_json_opts = PackageJsonOpts{
            .author = parsed.author,
            .description = parsed.description,
            .files = paths: {
                var lazy_paths = ArrayList([]const u8).initCapacity(
                    allo_arena,
                    parsed.files.len,
                ) catch @panic("OOM");

                for (parsed.files) |f| lazy_paths.append(
                    allo_arena,
                    f,
                ) catch @panic("OOM");

                break :paths lazy_paths.items;
            },
            .homepage = parsed.homepage,
            .keywords = parsed.keywords,
            .license = parsed.license,
            .main = if (parsed.main) |f| b.path(f) else null,
            .name = parsed.name,
            .publish_config = parsed.publishConfig,
            .repository = parsed.repository,
            .type = parsed.type,
            .types = if (parsed.types) |f| b.path(f) else null,
            .version = parsed.version.sem_ver,
        };
        break :blk .{ raw, pkg_json_opts };
    };

    const main_pkg_name = pkg_json_opts.name;

    const install_all = b.step(
        b.fmt("{s}:packages", .{main_pkg_name}),
        b.fmt("Create NPM packages for {s}", .{main_pkg_name}),
    );
    const publish_all = b.step(
        b.fmt("{s}:publish", .{main_pkg_name}),
        b.fmt("Publish NPM packages for {s} to a registry", .{main_pkg_name}),
    );

    var bin_dependencies = ArrayList(PackageJson.Dependency).initCapacity(
        allo_arena,
        opts.targets.len,
    ) catch @panic("OOM");

    var targets = std.ArrayListUnmanaged(AddonTarget).initCapacity(
        allo_arena,
        opts.targets.len,
    ) catch @panic("OOM");
    if (opts.win32_runtimes == Options.Win32Runtimes{}) @panic(
        "At least one target runtime is required for Windows targets",
    );

    for (opts.targets) |query| {
        if (query.os_tag != .windows) {
            targets.append(allo_arena, .{ .query = query }) catch @panic("OOM");
            continue;
        }

        if (opts.win32_runtimes.bun) targets.append(allo_arena, .{
            .query = query,
            .win32_runtime = .bun,
        }) catch @panic("OOM");

        if (opts.win32_runtimes.deno) targets.append(allo_arena, .{
            .query = query,
            .win32_runtime = .deno,
        }) catch @panic("OOM");

        if (opts.win32_runtimes.electron) targets.append(allo_arena, .{
            .query = query,
            .win32_runtime = .electron,
        }) catch @panic("OOM");

        if (opts.win32_runtimes.node) targets.append(allo_arena, .{
            .query = query,
            .win32_runtime = .node,
        }) catch @panic("OOM");
    }

    for (targets.items) |t| {
        const target = b.resolveTargetQuery(t.query);
        const pkg_name = packageName(
            b,
            main_pkg_name,
            opts.scoped_bin_packages,
            target.result,
            t.win32_runtime,
        );

        const dep = bin_dependencies.addOne(allo_arena) catch @panic("OOM");
        dep.* = .{ pkg_name, b.fmt("{f}", .{pkg_json_opts.version}) };

        const addon = Addon.create(b, .{
            .link_libc = opts.link_libc.get(opts.mode, target),
            .link_libcpp = opts.link_libcpp.get(opts.mode, target),
            .mode = opts.mode,
            .output_dir = .{
                .custom = b.pathJoin(&.{ opts.output_dir, pkg_name }),
            },
            .root_source_file = opts.root_source_file,
            .single_threaded = opts.single_threaded.get(opts.mode, target),
            .strip = opts.strip.get(opts.mode, target),
            .target = target,
            .tokota = opts.tokota,
            .win32_runtime = t.win32_runtime,
        });

        const pkg_json_contents = json.Stringify.valueAlloc(
            allo_arena,
            PackageJson{
                .name = pkg_name,
                .version = .{ .sem_ver = pkg_json_opts.version },
                .description = pkg_json_opts.description,
                .author = pkg_json_opts.author,
                .homepage = pkg_json_opts.homepage,
                .license = pkg_json_opts.license,
                .keywords = pkg_json_opts.keywords,

                .main = addon.basename,

                .publishConfig = pkg_json_opts.publish_config,
                .repository = pkg_json_opts.repository,

                .os = &.{nodeOs(target.result.os.tag)},
                .cpu = &.{nodeCpu(target.result)},
                .libc = if (nodeAbi(target.result)) |abi| &.{abi} else null,
            },
            .{
                .emit_null_optional_fields = false,
                .whitespace = .indent_2,
            },
        ) catch @panic("package.json write failed");

        const pkg_files = b.addWriteFiles();
        if (opts.pre_package) |pre| pkg_files.step.dependOn(pre);

        _ = if (opts.npmignore) |npmignore|
            pkg_files.addCopyFile(npmignore, ".npmignore");

        _ = if (opts.npmrc) |npmrc| pkg_files.addCopyFile(npmrc, ".npmrc");

        const pkg_dir = b.path(b.pathJoin(&.{
            // [TODO] Would be less brittle to get this path from the
            // `package_install` step above, but haven't figure out an easy way
            // to do that.
            "zig-out",
            opts.output_dir,
            pkg_name,
        }));

        const pkg_clean = b.addRemoveDirTree(pkg_dir);
        pkg_files.step.dependOn(&pkg_clean.step);
        addon.install.step.dependOn(&pkg_clean.step);

        const pkg_install = b.addInstallDirectory(.{
            .install_dir = .{ .custom = opts.output_dir },
            .install_subdir = pkg_name,
            .source_dir = pkg_files.getDirectory(),
        });
        pkg_install.step.dependOn(&pkg_files.step);
        pkg_install.step.dependOn(&addon.install.step);
        install_all.dependOn(&pkg_install.step);

        const publish = b.addSystemCommand(
            opts.publish_cmd orelse &.{ "npm", "publish" },
        );
        publish.setCwd(pkg_dir);

        publish.step.dependOn(install_all);
        publish_all.dependOn(&publish.step);

        const bin_pkg = bin_pkgs.addOne(allo_arena) catch @panic("OOM");
        bin_pkg.* = .{
            .addon = addon,
            .name = pkg_name,
            .package_json = pkg_files.add("package.json", pkg_json_contents),
            .publish = &publish.step,
            .target = target,
        };

        if (opts.configureLib) |configure| configure(b, bin_pkg.addon.lib);
    }

    const bin_filename = blk: {
        const stem = "addon.node";

        if (pkg_json_opts.main) |main| break :blk b.pathJoin(&.{
            main.dirname().src_path.sub_path,
            stem,
        });

        break :blk stem;
    };

    const bin_importer_filename = b.fmt("{s}.js", .{bin_filename});
    const bin_typings_filename = b.fmt("{s}.d.ts", .{bin_filename});

    const main_pkg_json_files = blk: {
        break :blk std.mem.concat(allo_arena, []const u8, &.{
            pkg_json_opts.files,
            &.{
                // [TODO] Only include these if not covered by package.json globs:
                bin_importer_filename,
                bin_typings_filename,
            },
        }) catch @panic("OOM");
    };

    const main_pkg = blk: {
        const package_json_contents = patched: {
            var opt_deps = std.json.ObjectMap.init(allo_arena);

            for (bin_dependencies.items) |dep| opt_deps
                .put(dep[0], .{ .string = dep[1] }) catch
                @panic("OOM");

            var files = std.json.Array.initCapacity(
                allo_arena,
                main_pkg_json_files.len,
            ) catch @panic("OOM");

            for (main_pkg_json_files) |f| {
                files.append(.{ .string = f }) catch @panic("OOM");
            }

            var raw_object = main_pkg_json.object;
            raw_object.put("files", .{ .array = files }) catch @panic("OOM");
            raw_object
                .put("optionalDependencies", .{ .object = opt_deps }) catch
                @panic("OOM");

            break :patched json.Stringify.valueAlloc(allo_arena, std.json.Value{
                .object = raw_object,
            }, .{
                .emit_null_optional_fields = false,
                .whitespace = .indent_2,
            }) catch @panic("OOM");
        };

        const pkg_files = b.addWriteFiles();
        if (opts.pre_package) |pre| pkg_files.step.dependOn(pre);

        _ = pkg_files.add(bin_importer_filename, index_js.generate(
            b,
            &arena,
            main_pkg_name,
            opts.scoped_bin_packages,
            targets.items,
        ) catch |err| switch (err) {
            error.OutOfMemory,
            error.WriteFailed,
            => @panic("OOM"),
        });

        _ = if (opts.npmignore) |npmignore|
            pkg_files.addCopyFile(npmignore, ".npmignore");

        _ = if (opts.npmrc) |npmrc| pkg_files.addCopyFile(npmrc, ".npmrc");

        _ = if (opts.root_typings_file) |typings|
            pkg_files.addCopyFile(typings, bin_typings_filename);

        _ = if (pkg_json_opts.main) |main|
            pkg_files.addCopyFile(main, main.src_path.sub_path);

        _ = if (pkg_json_opts.types) |typings|
            pkg_files.addCopyFile(typings, typings.src_path.sub_path);

        const pkg_json_paths = base.addPathsCopy(b, pkg_files);
        if (opts.pre_package) |pre| pkg_json_paths.step.dependOn(pre);

        for (pkg_json_opts.files) |user_file| pkg_json_paths.addPath(
            b.path(user_file),
            user_file,
        );

        const pkg_dir = b.path(b.pathJoin(&.{
            // [TODO] Would be less brittle to get this path from the
            // `package_install` step above, but haven't figure out an easy way
            // to do that.
            "zig-out",
            opts.output_dir,
            main_pkg_name,
        }));

        const pkg_clean = b.addRemoveDirTree(pkg_dir);
        pkg_files.step.dependOn(&pkg_clean.step);

        const package_install = b.addInstallDirectory(.{
            .install_dir = .{ .custom = opts.output_dir },
            .install_subdir = main_pkg_name,
            .source_dir = pkg_files.getDirectory(),
        });
        package_install.step.dependOn(&pkg_files.step);
        install_all.dependOn(&package_install.step);

        const publish = b.addSystemCommand(
            opts.publish_cmd orelse &.{ "npm", "publish" },
        );
        publish.setCwd(pkg_dir);

        publish_all.dependOn(&publish.step);

        // Don't publish if any native bin builds fail.
        publish.step.dependOn(install_all);

        // Publish all bin packages before publishing the main package.
        for (bin_pkgs.items) |bin| publish.step.dependOn(bin.publish);

        break :blk MainPackage{
            .name = main_pkg_name,
            .package_json = pkg_files.add(
                "package.json",
                package_json_contents,
            ),
            .publish = &publish.step,
        };
    };

    return .{
        .binary_packages = bin_pkgs
            .toOwnedSlice(allo_arena) catch @panic("OOM"),
        .install = install_all,
        .main_package = main_pkg,
        .publish = publish_all,
    };
}

/// Build steps and NPM package artifacts created for an addon.
pub const Packages = struct {
    /// Build steps and artifacts for the target-specific binary NPM packages.
    binary_packages: []const BinPackage,

    /// Build step for the installation of all generated NPM packages to the
    /// specific `Options.output_dir` within the install prefix location.
    ///
    /// Registered as a top-level `[lib name]:packages` step.
    install: *std.Build.Step,

    /// Build steps and artifacts for the main NPM package.
    main_package: MainPackage,

    /// Build step for the final NPM publish action. Invokes `npm publish` in
    /// each generated package directory.
    ///
    /// Registered as a top-level `[lib name]:publish` step.
    publish: *std.Build.Step,
};

/// Build steps and artifacts for the main addon NPM package.
pub const MainPackage = struct {
    name: []const u8,
    package_json: ?std.Build.LazyPath,
    publish: *std.Build.Step,
};

/// Build steps and artifacts for a single-target addon binary NPM package.
pub const BinPackage = struct {
    addon: Addon,
    name: []const u8,
    package_json: ?std.Build.LazyPath,
    publish: *std.Build.Step,
    target: std.Build.ResolvedTarget,
};

/// Addon NPM package build options.
pub const Options = struct {
    /// Callback for processing addon libraries.
    ///
    /// Provides a chance to add any necessary imports, linked libraries, etc to
    /// each target-specific addon.
    configureLib: ?*const fn (
        b: *std.Build,
        lib: *std.Build.Step.Compile,
    ) void = null,

    /// - `true`: requires a compilation that includes this Module to link libc.
    /// - `false`: causes a build failure if a compilation that includes this
    ///   Module would link libc.
    /// - `null` neither requires nor prevents libc from being linked.
    link_libc: TargetSpecificFlag = .{ .val = null },

    /// - `true`: requires a compilation that includes this Module to link
    ///   libc++.
    /// - `false`: causes a build failure if a compilation that includes this
    ///   Module would link libc++.
    /// - `null` neither requires nor prevents libc++ from being linked.
    link_libcpp: TargetSpecificFlag = .{ .val = null },

    /// Build optimization mode.
    mode: std.builtin.OptimizeMode,

    /// Path to a `.npmignore` file to include in each package output directory
    /// before publishing.
    ///
    /// May be useful for excluding specific files, or overriding an existing
    /// `.gitignore`, which is used by NPM in the absence of a `.npmignore`
    /// file (e.g. if publishing from a git-ignored `zig-out` directory, an
    /// empty `.npmignore` file will prevent NPM from ignoring files in the the
    /// `zig-out` directory).
    ///
    /// https://docs.npmjs.com/cli/v11/using-npm/developers#keeping-files-out-of-your-package
    npmignore: ?std.Build.LazyPath = null,

    /// Path to a `.npmrc` file to include in the build output.
    ///
    /// Used as configuration for NPM when publishing packages - not included in
    /// the list of files pushed to the NPM registry.
    npmrc: ?std.Build.LazyPath = null,

    /// Path to the root output directory for the NPM packages, relative to the
    /// install prefix path.
    output_dir: []const u8 = ".",

    /// The path to the project's `package.json` file. This will be copied to
    /// the main NPM package and updated to include `optionalDependencies` for
    /// each configured target-specific package.
    ///
    /// Relevant settings for the target-specific packages will be copied from
    /// this file.
    package_json: std.Build.LazyPath,

    /// If specified, all file-generation/copy and package-publish steps will
    /// depend on this step.
    ///
    /// Use this to sequence any other steps that need to run before installing
    /// packages to the output directory.
    pre_package: ?*std.Build.Step = null,

    /// Command line args (including the program name) to use for publishing
    /// each generated NPM package.
    ///
    /// Defaults to `&.{ "npm", "publish" }` - can be replaced with a command
    /// for a preferred package manager, or an invocation of a custom publish
    /// script, as needed.
    publish_cmd: ?[]const []const u8 = null,

    /// Path to the root source file that contains a call to
    /// `tokota.exportModule()` (or an import of a file that does).
    root_source_file: std.Build.LazyPath,

    /// Optional TypeScript `.d.ts` typings file for the addon exports.
    /// If specified, it is included in the main NPM package as the associated
    /// typings for the addon importer module (see `createPackages()`
    /// documentation).
    root_typings_file: ?std.Build.LazyPath = null,

    /// - `true`: addon binary packages are published under a scope matching the
    ///   the library name in `package.json`. If the library name is already
    ///   scoped, this is ignored and binary packages are published under the
    ///   same scope and name, along with a target-specific suffix.
    ///   e.g.:
    ///   - `"hello-z"` -> `"@hello-z/macos-aarch64"`
    ///   - `"@some-scope/hello-z"` -> `"@some-scope/hello-z-macos-aarch64"`
    ///
    /// - `false`: addon binary packages are published with a name matching
    ///   the library name in `package.json`, with a target-specific suffix.
    ///   e.g.:
    ///   - `"hello-z"` -> `"hello-z-macos-aarch64"`
    ///   - `"@some-scope/hello-z"` -> `"@some-scope/hello-z-macos-aarch64"`
    scoped_bin_packages: bool = false,

    /// Iff `true`, the addon binaries are compiled in single-threaded mode.
    single_threaded: TargetSpecificFlag = .{ .val = null },

    /// Whether or not to [strip](https://en.wikipedia.org/wiki/Strip_(Unix))
    /// the addon binary.
    strip: TargetSpecificFlag = .{ .val = null },

    /// Optional tokota module configuration.
    tokota: Addon.Options.Tokota = .{},

    /// Build targets for the addon. A separate addon binary and NPM package
    /// will be created for each target and included in the
    /// `optionalDependencies` the main NPM package's `package.json` file.
    ///
    /// Caller is responsible for ensuring that the addon can be cross-compiled
    /// successfully on the current host.
    targets: []const std.Target.Query,

    /// When targeting Windows, addon binaries need to be linked against a
    /// specific executable name (node.exe, by default). Override this setting
    /// to specify different/additional target runtimes to support on Windows.
    ///
    /// This is a temporary workaround until a better solution is found, or
    /// until Zig provides delay-load support to enable lazily linking to the
    /// calling runtime when first loaded:
    /// https://github.com/ziglang/zig/issues/7049
    ///
    /// For now, this will result in separate binary packages for each selected
    /// runtime. The appropriate binary package will be conditionally imported,
    /// by the `addon.js` entrypoint in the main package, based on the detected
    /// runtime - however, all packages matching the user's architecture will
    /// be downloaded from the NPM registry, so keep that in mind for large
    /// binaries.
    win32_runtimes: Win32Runtimes = .{ .node = true },

    const Win32Runtimes = packed struct {
        bun: bool = false,
        deno: bool = false,
        electron: bool = false,
        node: bool = false,
    };
};

pub const TargetSpecificFlag = union(enum) {
    cb: *const fn (std.builtin.OptimizeMode, std.Build.ResolvedTarget) ?bool,
    val: ?bool,

    pub fn get(
        self: TargetSpecificFlag,
        mode: std.builtin.OptimizeMode,
        target: std.Build.ResolvedTarget,
    ) ?bool {
        return switch (self) {
            .cb => |cb| cb(mode, target),
            .val => |val| val,
        };
    }
};

const ParsedJsonValue = std.json.Parsed(std.json.Value);

const PackageJsonOpts = struct {
    author: ?[]const u8 = null,
    description: ?[]const u8 = null,
    files: []const []const u8 = &.{},
    homepage: ?[]const u8 = null,
    keywords: ?[]const []const u8 = null,
    license: ?PackageJson.License = null,
    main: ?std.Build.LazyPath = null,
    name: []const u8,
    publish_config: ?PackageJson.PublishConfig = null,
    repository: ?PackageJson.Repository = null,
    type: ?PackageJson.Type = null,
    types: ?std.Build.LazyPath = null,
    version: std.SemanticVersion,
};

fn parsePackageJson(
    b: *std.Build,
    arena: *std.heap.ArenaAllocator,
    path: std.Build.LazyPath,
) struct { std.json.Value, PackageJson } {
    const allo = arena.allocator();

    var io_threaded = std.Io.Threaded.init(allo, .{});
    defer io_threaded.deinit();

    const io = io_threaded.ioBasic();

    const file_path = path
        .getPath3(b, null)
        .toString(allo) catch @panic("OOM");

    const file = std.Io.Dir.openFileAbsolute(io, file_path, .{
        .mode = .read_only,
    }) catch |err| @panic(b.fmt(
        "{t} - Unable to read package.json file from {s}\n",
        .{ err, path.src_path.sub_path },
    ));
    defer file.close(io);

    var buf: [1024]u8 = undefined;
    var file_reader = file.reader(io, &buf);

    var json_reader = std.json.Reader.init(allo, &file_reader.interface);
    const raw = std.json.parseFromTokenSourceLeaky(
        std.json.Value,
        allo,
        &json_reader,
        .{},
    ) catch |err| @panic(b.fmt(
        "{t} - Unable to parse package.json file from {s}\n",
        .{ err, path.src_path.sub_path },
    ));

    const known_fields = std.json.parseFromValueLeaky(PackageJson, allo, raw, .{
        .ignore_unknown_fields = true,
    }) catch |err| @panic(b.fmt(
        "{t} - Unable to parse package.json file {s}\n",
        .{ err, path.src_path.sub_path },
    ));

    return .{ raw, known_fields };
}
