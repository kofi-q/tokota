//! Tokota provides bindings for the
//! [Node-API](https://nodejs.org/docs/latest/api/n-api.html#node-api), to
//! enable NodeJS native addon development in Zig. Out of a personal need, this
//! library has evolved to include a comptime-based framework for Zig <> JS
//! communication and type conversion, in attempt to
//! [cut down](https://github.com/kofi-q/tokota/examples/add/main.zig)
//! on [boilerplate](https://github.com/kofi-q/tokota/examples/add/main_hard_mode.zig),
//! while keeping the overhead minimal.
//!
//!
//! ```zig
//! //! addon.zig
//!
//! const std = @import("std");
//! const tokota = @import("tokota");
//!
//! comptime {
//!     tokota.exportModule(@This());
//! }
//!
//! pub fn hello(name: tokota.TinyStr(16)) ![]const u8 {
//!     var buf: [32]u8 = undefined;
//!     return std.fmt.bufPrint(&buf, "{}, how be?", .{name});
//! }
//!
//! pub fn add(a: i32, b: i32) i32 {
//!     return a + b;
//! }
//! ```
//!
//! ```js
//! // main.js
//!
//! const addon = require("./addon.node");
//!
//! console.log(addon.hello("Chale"));
//! console.log("10 + 5 =", addon.add(10, 5));
//! ```
//!
//! ```console
//! $ node ./main.js
//! Chale, how be?
//! 10 + 5 = 15
//! ```

const A = @This();

const std = @import("std");
const builtin = @import("builtin");
const comptimePrint = std.fmt.comptimePrint;

const root = @import("root");

pub const AnyPtr = *anyopaque;
pub const AnyPtrConst = *const anyopaque;
pub const Api = @import("object/api.zig").Api;
pub const Array = @import("array/Array.zig");
pub const ArrayBuffer = @import("array_buffer/ArrayBuffer.zig");
pub const ArrayType = @import("array_buffer/typed_array.zig").ArrayType;
pub const BigInt = @import("number/BigInt.zig");
pub const Buffer = @import("array_buffer/Buffer.zig");
pub const Call = @import("function/call.zig").Call;
pub const CallT = @import("function/call.zig").CallT;
pub const Class = @import("object/Class.zig");
pub const ClassZ = @import("object/class_z.zig").ClassZ;
pub const Cleanup = @import("heap/cleanup.zig").Cleanup;
pub const CleanupAsync = @import("heap/cleanup.zig").CleanupAsync;
pub const Closure = @import("function/closure.zig").Closure;
pub const DataView = @import("array_buffer/DataView.zig");
pub const Date = @import("date/Date.zig");
pub const Deferred = @import("async/promise.zig").Deferred;
pub const enums = @import("object/enums.zig");
pub const Env = @import("env.zig").Env;
pub const Err = @import("error/error.zig").Err;
pub const ErrorDetails = @import("error/types.zig").ErrorDetails;
pub const ErrorInfo = @import("error/types.zig").ErrorInfo;
pub const External = @import("heap/external.zig").External;
pub const Finalizer = @import("heap/Finalizer.zig");
pub const Fn = @import("function/Fn.zig");
pub const HandleScope = @import("lifetime/handle_scope.zig").HandleScope;
pub const HandleScopeEscapable = @import("lifetime/handle_scope.zig").HandleScopeEscapable;
pub const Int = @import("number/int.zig").Int;
pub const napi = @import("napi.zig");
pub const napiCb = @import("function/callback.zig").napiCb;
pub const NapiStatus = @import("napi.zig").Status;
pub const NapiVersion = @import("options").NapiVersion;
pub const Object = @import("object/Object.zig");
pub const Options = @import("options").Options;
pub const panic = @import("error/error.zig").panic;
pub const panicStd = @import("error/error.zig").panicStd;
pub const Promise = @import("async/promise.zig").Promise;
pub const Property = @import("object/property.zig").Property;
pub const Ref = @import("lifetime/ref.zig").Ref;
pub const StrLatin1Owned = @import("string/types.zig").StrLatin1Owned;
pub const StrUtf16Owned = @import("string/types.zig").StrUtf16Owned;
pub const Symbol = @import("global/Symbol.zig");
pub const TinyStr = @import("string/tiny_str.zig").TinyStr;
pub const TypedArray = @import("array_buffer/typed_array.zig").TypedArray;
pub const TypedArrayExtractError = @import("array_buffer/Val.zig").TypedArrayExtractError;
pub const Uint = @import("number/int.zig").Uint;
pub const Val = @import("val.zig").Val;
pub const ValType = @import("val.zig").ValType;

/// Types related to NodeJS async operations.
pub const Async = struct {
    const mod_task = @import("async/task.zig");
    const mod_work = @import("async/worker.zig");

    pub const Complete = mod_work.Complete;
    pub const CompleteT = mod_work.CompleteT;
    pub const Execute = mod_work.Execute;
    pub const ExecuteT = mod_work.ExecuteT;
    pub const Resource = @import("async/Resource.zig");
    pub const Task = mod_task.Task;
    pub const Worker = mod_work.Worker;
};

/// Types related to Threadsafe Functions, providing a communication channel
/// between secondary/background threads and the main JS thread.
///
/// `threadsafe.Fn` and `threadsafe.FnT` are the main points of interest here.
pub const threadsafe = struct {
    const mod = @import("async/threadsafe_fn.zig");

    pub const Callback = mod.Callback;
    pub const CallMode = mod.CallMode;
    pub const Config = mod.Config;
    pub const Fn = mod.Fn;
    pub const FnT = mod.FnT;
    pub const Proxy = mod.Proxy;
    pub const ReleaseMode = mod.ReleaseMode;
};

pub const int_safe_max = @import("number/int.zig").int_safe_max;
pub const int_safe_min = @import("number/int.zig").int_safe_min;

pub const log = std.log.scoped(options.log_scope);

/// Library-wide options for customising functionality and toggling features
/// as needed.
/// To override the defaults, expose a `pub const tokota_options: Options` in
/// the root file of the importing module.
///
/// ## Example
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
pub const options: Options = if (@hasDecl(root, "tokota_options"))
    root.tokota_options
else
    .{};

/// Registers public declarations in the given type as named JS module exports.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// const internal = "Not exported";
///
/// pub const TUNING_HZ = 440;
/// pub const Note = enum { A, B, C };
///
/// pub fn foo() bool {
///     return true;
/// }
///
/// pub const some_namespace = struct {
///     pub fn bar() struct { []const u8, bool, u32 } {
///         return .{ "one", true, 3 };
///     }
/// };
///
/// pub const Encabulator = t.ClassZ("Turbo", struct {
///     pub fn constructor(call: t.Call) !t.Object {
///         return call.this();
///     }
///
///     pub fn encabulate(cb: t.Fn) bool {
///         runEncabulation(cb);
///         return true;
///     }
/// });
/// ```
///
/// #### The above is equivalent to the following in JS:
///
/// ```js
/// const internal = "Not exported";
///
/// export const TUNING_HZ = 440;
/// export const Note = { A: 0, B: 1, C: 2 };
///
/// export function foo() {
///   return true;
/// }
///
/// export const some_namespace = {
///   bar() {
///     return ["one", true, 3];
///   }
/// };
///
/// export const Encabulator = class Turbo {
///   constructor() {
///     // no-op
///   }
///
///   encabulate(cb) {
///     runEncabulation(cb);
///     return true;
///   }
/// }
/// ```
pub fn exportModule(comptime mod: anytype) void {
    exportModuleWithInit(mod, null);
}

/// Initialization function used in `exportModuleWithInit()`. Called once when
/// the addon is first loaded in a NodeJS process (may be called multiple times
/// if there are multiple NodeJS child processes running).
///
/// `exports` is a JS Object containing properties derived from the exported
/// Zig namespace. This object can be modified as needed and then returned.
/// Returning `null` will also cause the `exports` object to get returned to JS.
///
/// Returning a different JS value will replace the JS exports wth the new
/// value, which may be useful for customising exports for an addon. See
/// `exportModuleWithInit()` for an example.
pub const InitFn = fn (env: Env, exports: Val) anyerror!?Val;

/// Equivalent to `exportModule`, but additionally accepts an `InitFn` to run
/// after setting up the initial exports.
///
/// Enables adding more complex/custom module exports, if needed, or doing any
/// necessary instance-wide setup.
///
/// ## Example
/// ```zig
/// //! addon.zig
///
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModuleWithInit(@This(), addonInit);
/// }
///
/// fn addonInit(env: t.Env, exports_original: t.Val) !?t.Val {
///     _ = exports_original;
///
///     // Replace module exports with a single, top-level function.
///     return (try env.function(hello)).ptr;
/// }
///
/// fn hello() []const u8 {
///     return "Hi.";
/// }
/// ```
///
/// ```js
/// // main.js
///
/// const assert = require("node:assert");
/// const hello = require("./addon.node");
///
/// assert.equal(typeof hello, "function");
/// assert.equal(hello(), "Hi.");
/// ```
pub fn exportModuleWithInit(
    comptime mod: anytype,
    comptime init_fn: ?InitFn,
) void {
    const entry_points = struct {
        fn apiVersion() callconv(.c) NapiVersion {
            return options.napi_version;
        }

        fn registerModule(env: Env, mod_js: Val) callconv(.c) ?Val {
            const exports = defineExports(env, mod_js, mod) orelse return null;

            const override: ?Val = blk: {
                if (init_fn) |init| {
                    break :blk init(env, exports) catch |err| panic(
                        "Module initialization failed.",
                        @errorName(err),
                    );
                }

                break :blk null;
            };

            return override orelse exports;
        }
    };

    @export(&entry_points.apiVersion, .{
        .linkage = .strong,
        .name = symbol_name_get_api_version,
    });

    @export(&entry_points.registerModule, .{
        .linkage = .strong,
        .name = symbol_name_register_module,
    });
}

/// https://github.com/nodejs/node-api-headers/blob/v1.5.0/include/node_api.h#L51
pub const napi_module_version = 1;

/// Name of the exported symbol needed by the NodeJS engine to load an addon.
///
/// https://github.com/nodejs/node-api-headers/blob/v1.5.0/include/node_api.h#L65
pub const symbol_name_register_module = comptimePrint(
    "{s}_v{d}",
    .{
        switch (builtin.os.tag) {
            .wasi => "napi_register_wasm",
            else => "napi_register_module",
        },
        napi_module_version,
    },
);

/// Name of the exported symbol needed by the NodeJS engine to determine the
/// version of the Node-API that an addon was built to target.
///
/// https://github.com/nodejs/node-api-headers/blob/v1.5.0/include/node_api.h#L68
pub const symbol_name_get_api_version = comptimePrint(
    "{s}_v{d}",
    .{ "node_api_module_get_api_version", napi_module_version },
);

/// Node engine version information, as returned by `Env.nodeVersion()`.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_get_node_version
pub const NodeVersion = extern struct {
    major: u32,
    minor: u32 = 0,
    patch: u32 = 0,
    release: [*:0]const u8 = "",

    pub fn format(
        self: NodeVersion,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: std.Io.AnyWriter,
    ) !void {
        try std.fmt.format(writer, "{s} v{d}.{d}.{d}", .{
            self.release,
            self.major,
            self.minor,
            self.patch,
        });
    }
};

fn defineExports(env: Env, exports: Val, comptime mod: anytype) ?Val {
    const Mod, const method_data = switch (@TypeOf(mod)) {
        type => .{ mod, {} },
        else => |t| .{ t, mod },
    };

    switch (@typeInfo(Mod)) {
        .@"struct" => {
            exports.object(env).defineApi(mod, method_data) catch |err| {
                switch (err) {
                    Err.PendingException => {},
                    else => env.throwOrPanic(.{
                        .code = @errorName(err),
                        .msg = "Module initialization failed",
                    }),
                }
                return null;
            };

            return exports;
        },

        .@"fn" => return env.function(mod) catch |err| {
            switch (err) {
                Err.PendingException => {},
                else => env.throwOrPanic(.{
                    .code = @errorName(err),
                    .msg = "Module initialization failed",
                }),
            }
            return null;
        },

        else => @compileError(
            "[ERROR] struct or fn required for module export.",
        ),
    }
}
