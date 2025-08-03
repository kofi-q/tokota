//! Build units and artifacts created for a NodeJS native addon.

const std = @import("std");

const node_dll = @import("windows/node_dll.zig");
const node_stub_so = @import("linux/node_stub_so.zig");
const targets = @import("targets.zig");

const Addon = @This();

/// The basename of the `.node` output file, based on `Options.name`.
basename: []const u8,

/// Binary file installation step for the addon binary.
///
/// The install destination is based on `Options.output_dir`.
install: *std.Build.Step.InstallFile,

/// Shared library compile step unit for the addon.
lib: *std.Build.Step.Compile,

/// Root module for the shared library.
root_module: *std.Build.Module,

/// Node-API Addon build options.
pub const Options = struct {
    /// The table of other modules that this module can access via `@import`.
    ///
    /// Imports are allowed to be cyclical, so this table can be added to after
    /// the `Module` is created via `addImport`.
    imports: []const std.Build.Module.Import = &.{},

    /// - `true` requires a compilation that includes this Module to link libc.
    /// - `false` causes a build failure if a compilation that includes this
    ///      Module would link libc.
    /// - `null` neither requires nor prevents libc from being linked.
    link_libc: ?bool = null,

    /// - `true` requires a compilation that includes this Module to link libc++.
    /// - `false` causes a build failure if a compilation that includes this
    ///      Module would link libc++.
    /// - `null` neither requires nor prevents libc++ from being linked.
    link_libcpp: ?bool = null,

    /// Build optimization mode. Defaults to the build context's mode.
    mode: std.builtin.OptimizeMode,

    /// Library name for the addon binary.
    /// The output binary will be named `<name>.node`.
    name: []const u8 = "addon",

    /// Path to the output file, relative to the install prefix path. Should end
    /// in a `.node` extension to simplify loading via JS.
    output_dir: std.Build.InstallDir = .prefix,

    /// Root file that contains  a call to `tokota.exportModule()` (or an import
    /// of a file that does).
    root_source_file: std.Build.LazyPath,

    /// Iff `true`, the addon binary is compiled in single-threaded mode.
    single_threaded: ?bool = null,

    /// Whether or not to [strip](https://en.wikipedia.org/wiki/Strip_(Unix))
    /// the addon binary.
    strip: ?bool = null,

    /// Build target OS/architecture.
    target: std.Build.ResolvedTarget,

    /// Optional tokota module configuration.
    tokota: Tokota = .{},

    /// When targeting Windows, the addon needs to be linked against a specific
    /// executable name (node.exe, by default). Specify a different target
    /// runtime if the addon will be loaded within a non-Node.js runtime.
    ///
    /// This is a temporary workaround until a better solution is found, or
    /// until Zig provides delay-load support to enable lazily linking to the
    /// calling runtime when first loaded:
    /// https://github.com/ziglang/zig/issues/7049
    win32_runtime: targets.Runtime = .node,

    pub const Tokota = struct {
        /// The tokota build dependency, via `std.Build.dependency()`, if
        /// it is being imported with a name other than `"tokota"`.
        ///
        /// Defaults to a dependency created via
        /// `std.Build.dependency("tokota", ...)`.
        dep: ?*std.Build.Dependency = null,

        /// The name for the tokota module import.
        import_name: []const u8 = "tokota",
    };
};

/// Creates a shared library with a Tokota module dependency and a file install
/// step for the final `.node` output binary file.
pub fn create(b: *std.Build, opts: Options) Addon {
    const dep_tokota = opts.tokota.dep orelse b.dependency("tokota", .{
        .optimize = opts.mode,
        .target = opts.target,
    });

    const mod = b.createModule(.{
        .imports = &.{.{
            .name = opts.tokota.import_name,
            .module = dep_tokota.module("tokota"),
        }},
        .link_libc = opts.link_libc,
        .link_libcpp = opts.link_libcpp,
        .optimize = opts.mode,
        .single_threaded = opts.single_threaded,
        .strip = opts.strip,
        .root_source_file = opts.root_source_file,
        .target = opts.target,
    });

    for (opts.imports) |import| mod.addImport(import.name, import.module);

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = opts.name,
        .root_module = mod,
    });

    switch (opts.target.result.os.tag) {
        .windows => linkNodeStubWin32(b, lib, .{
            .dep_tokota = opts.tokota.dep,
            .win32_runtime = opts.win32_runtime,
        }),
        else => lib.linker_allow_shlib_undefined = true,
    }

    const basename = b.fmt("{s}.node", .{opts.name});
    const install = b.addInstallFileWithDir(
        b.addInstallArtifact(lib, .{}).emitted_bin.?,
        opts.output_dir,
        basename,
    );

    return .{
        .basename = basename,
        .install = install,
        .lib = lib,
        .root_module = mod,
    };
}

pub const LibnodeStubOpts = struct {
    /// The Tokota build dependency, via std.Build.dependency(), if it is being
    /// imported with a name other than "tokota". Defaults to a dependency
    /// created via std.Build.dependency("tokota")
    dep_tokota: ?*std.Build.Dependency = null,

    /// When targeting Windows, the addon needs to be linked against a specific
    /// executable name (node.exe, by default). Specify a different target
    /// runtime if the addon will be loaded within a non-Node.js runtime.
    ///
    /// This is a temporary workaround until a better solution is found, or
    /// until Zig provides delay-load support to enable lazily linking to the
    /// calling runtime when first loaded:
    /// https://github.com/ziglang/zig/issues/7049
    win32_runtime: targets.Runtime = .node,
};

/// Links a stub library containing Node-API symbols to enable compiling addon
/// code for use outside a Node process (e.g. when running native tests via
/// `std.testing.refAllDecls[Recursive]`.
pub fn linkNodeStub(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    opts: LibnodeStubOpts,
) void {
    switch (lib.rootModuleTarget().os.tag) {
        .linux => linkNodeStubLinux(b, lib, opts),
        .windows => linkNodeStubWin32(b, lib, opts),
        else => lib.linker_allow_shlib_undefined = true,
    }
}

/// Links a stub shared library containing Node-API symbols to enable compiling
/// addon code for use outside a Node process (e.g. when running native tests
/// via `std.testing.refAllDecls[Recursive]`.
pub fn linkNodeStubLinux(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    opts: LibnodeStubOpts,
) void {
    const mode = lib.root_module.optimize.?;
    const target = lib.root_module.resolved_target;
    lib.linkLibrary(node_stub_so.build(b, mode, target, opts.dep_tokota));
}

/// Links a stub DLL containing Node-API symbols to enable compiling addon
/// code for use outside a Node process (e.g. when running native tests via
/// `std.testing.refAllDecls[Recursive]`.
pub fn linkNodeStubWin32(
    b: *std.Build,
    lib: *std.Build.Step.Compile,
    opts: LibnodeStubOpts,
) void {
    const node_dll_step, const node_dll_path = node_dll.build(
        b,
        opts.win32_runtime,
        lib.root_module.optimize.?,
        lib.rootModuleTarget(),
        opts.dep_tokota,
    );
    lib.step.dependOn(&node_dll_step.step);
    lib.addLibraryPath(node_dll_path.dirname());
    lib.linkSystemLibrary2("node", .{});
}
