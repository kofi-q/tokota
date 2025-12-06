const std = @import("std");

/// Library-wide options for customising functionality and toggling features
/// as needed.
///
/// To override the defaults, expose a `pub const tokota_options: Options` in
/// the root file of the importing module:
///
/// ```zig
/// const tokota = @import("tokota");
///
/// pub const tokota_options = tokota.Options{
///     .lib_name = "hello-z",
///     .napi_version = .v9,
/// };
///
/// comptime {
///     tokota.exportModule(@This());
/// }
///
/// pub fn hello() []const u8 {
///   return "Hi";
/// }
/// ```
pub const Options = struct {
    /// Enables creation of JS `ArrayBuffer`s backed by native-owned data.
    ///
    /// > #### ⚠ NOTE
    /// > This is not supported by all runtimes, for safety reasons,
    /// and is recommended to be used only if absolutely necessary. Consider
    /// allocating an `ArrayBuffer` with `Env.arrayBuffer()`  and passing the
    /// underlying buffers around instead, if feasible.
    ///
    /// https://nodejs.org/docs/latest/api/n-api.html#napi_create_external_arraybuffer
    allow_external_buffers: bool = false,

    /// Name of the addon library - used in error messages and default async
    /// resource names.
    lib_name: []const u8 = "Tokota:NodeAddon",

    /// Scope tag for logs originating from Tokota.
    ///
    /// Logging for this scope can be filtered, if needed
    /// (see `log_scope_levels` in `std.Options`).
    log_scope: @EnumLiteral() = .tokota,

    /// Controls which Node-API methods are available at
    /// compile-time and, by extension, which JS runtime versions your addon will
    /// be compatible with.
    napi_version: NapiVersion = .v8,

    pub fn format(self: Options, writer: *std.Io.Writer) !void {
        try writer.print(
            Fmt.underline(
                \\[{[lib_name]s}] Tokota Options:
            ) ++
                \\
                \\  allow_external_buffers: {[allow_external_buffers]}
                \\  log_scope: {[log_scope]}
                \\  napi_version: {[napi_version]}
                \\
            ,
            self,
        );
    }
};

/// The Node-API version to build against. Determines which portions of the
/// API are available and, by extension, which versions of Node will be
/// compatible with the addon.
///
/// The default `NapiVersion` is set to `v8` - to override the defaults, expose
/// an `Options` decl in the root file of the importing module:
///
/// ```zig
/// const tokota = @import("tokota");
///
/// pub const tokota_options = tokota.Options{
///     .napi_version = .v9,
/// };
///
/// comptime {
///     tokota.exportModule(@This());
/// }
///
/// pub fn hello() []const u8 {
///   return "Hi";
/// }
/// ```
///
/// https://nodejs.org/docs/latest/api/n-api.html#node-api-version-matrix
pub const NapiVersion = enum(i32) {
    /// v16.0.0 and all later versions.
    v8 = 8,

    /// Node v18.17.0+, 20.3.0+, 21.0.0 and all later versions.
    ///
    /// Enables:
    /// - `Env.errSyntax()`
    /// - `Env.moduleFileName()`
    /// - `Env.symbolFor()`
    /// - `Env.throwErrSyntax()`
    v9 = 9,

    /// Node v22.14.0+, 23.6.0+ and all later versions.
    ///
    /// Enables:
    /// - `ArrayBuffer.buffer()`
    /// - `Env.propKey()`
    /// - `Env.propKeyLatin1()`
    /// - `Env.propKeyUtf16()`
    /// - `Env.strLatin1Owned()`
    /// - `Env.strUtf16Owned()`
    /// - `Val.ref()`
    v10 = 10,

    /// Node@latest
    ///
    /// Enables all available features, including both experimental features and
    /// experimental updated behaviour for existing APIs.
    ///
    /// Useful when developing against upcoming Node-API versions.
    ///
    /// https://nodejs.org/docs/latest/api/documentation.html#stability-index
    experimental = std.math.maxInt(i32),

    pub inline fn isAtLeast(self: NapiVersion, min_version: NapiVersion) bool {
        return @intFromEnum(self) >= @intFromEnum(min_version);
    }
};

const Fmt = struct {
    pub fn underline(comptime fragment: []const u8) []const u8 {
        return "\x1b[4m" ++ fragment ++ "\x1b[0m";
    }
};
