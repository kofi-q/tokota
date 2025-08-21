const std = @import("std");

const NapiVersion = @import("options").NapiVersion;
const options = @import("root.zig").options;

const comptimePrint = std.fmt.comptimePrint;

/// Tags a function as requiring a minimum Node-API version.
///
/// Used internally to disable API methods that are incompatible with the
/// selected Node-API version.
///
/// See `Options`.
pub fn requireNapiVersion(comptime version: NapiVersion) void {
    if (!options.napi_version.isAtLeast(version)) @compileError(comptimePrint(
        \\[ Node-API Version Mismatch ]
        \\Expected `.{[0]t}` or greater, got `.{[1]t}`.
        \\To use this method, add a `pub const tokota_options: tokota.Options`
        \\declaration to the root source file and set `napi_version`
        \\to `.{[0]s}` or greater.
        \\
        \\(❓) You may need to build with the `-freference-trace` flag to
        \\     find the relevant source location.
        \\
    , .{
        version,
        options.napi_version,
    }));
}

/// Asserts that the `Options.allow_external_buffers` feature is enabled.
///
/// External buffers are JS `ArrayBuffer` objects or NodeJs `Buffer` objects,
/// backed by native-owned memory.
///
/// Used internally to disable API methods that require the
/// `allow_external_buffers` option to be enabled.
///
/// See `Options`.
pub fn requireExternalBuffers() void {
    if (!options.allow_external_buffers) @compileError(
        \\External (native-owned) buffers are currently disabled.
        \\To use this method, add a `pub const tokota_options: tokota.Options`
        \\declaration to the root source file and set `allow_external_buffers`
        \\to `true`.
        \\
        \\(❓) You may need to build with the `-freference-trace` flag to
        \\     find the relevant source location.
        \\
    );
}
