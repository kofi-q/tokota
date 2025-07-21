# Tokota

` › build / package / publish multi-platform NodeJS addons written in Zig 🧡 `

[Documentation ↗](https://kofi-q.github.io/tokota) | | [Overview](#overview) | | [Versions](#versions) | | [Getting Started](#getting-started) | | [Beyond Hello...](#beyond-hello)

```zig
//! addon.zig

const std = @import("std");
const tokota = @import("tokota");

comptime {
    tokota.exportModule(@This());
}

pub fn hello(name: tokota.TinyStr(16)) ![]const u8 {
    var buf: [32]u8 = undefined;
    return std.fmt.bufPrint(&buf, "{}, how be?", .{name});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}
```

```js
// main.js

const addon = require("./addon.node");

console.log(addon.hello("Chale"));
console.log("10 + 5 =", addon.add(10, 5));
```

```console
$ node ./main.js
Chale, how be?
10 + 5 = 15
```

## Overview

Tokota provides bindings for the [Node-API](https://nodejs.org/docs/latest/api/n-api.html#node-api), to enable NodeJS native addon development in Zig. Out of a personal need, this library has evolved to include a comptime-based framework for Zig <> JS communication and type conversion, in attempt to [cut down](./examples/add/main.zig) on [boilerplate](./examples/add/main_hard_mode.zig), while trying to keep the overhead minimal.

You may find this useful if:

- You are working in a primarily NodeJS-based codebase and looking for a quick way to integrate some Zig code.
- You are working on a Zig library and looking to publish NodeJS addons for JS clients.
- You are "just tinkering" with Zig and are five levels deep in a series of branching side-projects and not really sure how you got here.

In any case, obligatory disclaimer: this API is still changing — sometimes, in response to changes in the Zig language — and may take a while to settle.

## Platforms

`› Tested on: Linux, MacOS, Windows`

Building and packaging addons with Tokota should work wherever Zig works...in theory. Only the above operating systems have been tested so far. Feel free to reach out if you are unable to build on or for a specific platform.

## Versions

### Zig

Tokota requires Zig version `v0.15.0-dev.1149+4e6a04929` or later (tested up to the version in [`.zigversion`](.zigversion)).

### NodeJS

`› Tested with v16.0.0 - v24.2.0`

The minimum (and default) Node-API version supported by Tokota is [`8`](https://nodejs.org/docs/latest/api/n-api.html#node-api-version-matrix). In theory, based on the Node-API documentation, this enables building addons compatible with the following NodeJS versions:

> v12.22.0+, v14.17.0+, v15.12.0+, 16.0.0 and all later versions.

However, I've had issues with versions prior to **`v16.0.0`** (most prohibitively, incorrect CPU architecture detection for Apple Silicon Macs) and don't think it's worth investing any effort there. It may still be possible to build bare addon binaries for single-target use (not using the NPM packaging helpers) which are compatible with lower versions, but this is untested.

> [!NOTE]
>
> Using parts of the Tokota API that require selecting higher Node-API versions will further limit which NodeJS versions are compatible with an addon. See the Node-API [version matrix](https://nodejs.org/docs/latest/api/n-api.html#node-api-version-matrix) for more info.
>
> For details on how to select a Node-API version, see [Configuring Tokota](#configuring-tokota) below.

### Bun

`› Last tested with v1.2.18`

Bun provides an implementation of the Node-API.

> [!IMPORTANT]
>
> Although most addons that work with NodeJS should work with Bun as well, full API coverage is still a [work-in-progress](https://github.com/oven-sh/bun/issues/158) at the time of writing, so I'd recommend testing your library fully with Bun if you intend to explicitly support it. [Here's a list of test exceptions](https://github.com/search?q=repo%3Akofi-q%2Ftokota+%22%5BSKIP%5D+Bun%3A%22&type=code) being made in this repo for Bun at the moment (a list that has been shrinking rapidly, for what it's worth).

### Deno

`› Last tested with v2.4.0`

Deno also provides a work-in-progress (at the time of writing) Node-API implementation.

> [!IMPORTANT]
>
> There may be a few bugs/behavioural differences in parts of the API, so I'd recommend testing your library fully with Deno if you intend to explicitly support it. [Here's a list of test exceptions](https://github.com/search?q=repo%3Akofi-q%2Ftokota+%22%5BSKIP%5D+Deno%3A%22&type=code) being made in this repo for Deno at the moment.

### Electron

`› Tested with v15.0.0 - v36.2.0`

Electron embeds a specific NodeJS in its runtime and, for the most part, is compatible with the same corresponding Node-API versions. The earliest Electron version compatible with Node-API version 8 is `v15.0.0`. As with [NodeJS](#nodejs) above, opting in to higher Node-API versions will further limit which versions of Electron are supported by an addon.

## Getting Started

If you're getting Zig set up for the first time, welcome! Take a look at the [Zig docs](https://ziglang.org/learn/getting-started/) first. When you're ready:

```sh
cd path/to/project && zig init
```

Add Tokota, as a dependency, to your `build.zig.zon` file:

```sh
zig fetch --save "git+https://github.com/kofi-q/tokota.git#zig-v0.15.0"
```

Then, import the dependency in `build.zig` and create an addon build step:

```zig
//! build.zig

const std = @import("std");
const tokota = @import("tokota");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const addon = tokota.Addon.create(b, .{
        .name = "leftpad-z",
        .mode = mode,
        .target = target,
        .root_source_file = b.path("src/root.zig"),
        .output_dir = .{ .custom = "../lib" },
    });

    // Add other settings/imports/linked libraries your addon may need:
    // addon.root_module.addImport("simd-leftpad", ...);
    // addon.lib.linkSystemLibrary("libleftpad-gpu");

    b.getInstallStep().dependOn(&addon.install.step);
}
```

> [!TIP]
>
> For reference on building and publishing multi-platform NPM packages, take a look at the [NPM example](./examples/npm/build.zig) or the documentation for [`build.npm.createPackages`](https://kofi-q.github.io/tokota/build/#tokota_build.npm.createPackages).

The above creates a compilation unit with a `"tokota"` import which can be used in your addon code. See [`build.Addon.Options`](https://kofi-q.github.io/tokota/build/#tokota_build.Addon.Options) for more details on addon binary creation.

Now, create your root source file:

```zig
//! src/root.zig

const tokota = @import("tokota");

comptime {
    tokota.exportModule(@This());
}

pub fn leftPad(input: tokota.TinyStr(31), min_width: u5) []const u8 {
    var buf: [31]u8 = undefined;

    const str_len = input.len;
    const pad_len = min_width -| str_len;

    @memset(buf[0..pad_len], ' ');
    @memcpy(buf[pad_len..][0..str_len], input.slice());

    return buf[0..min_width];
}
```

With all that done, run the default build step from the project root:

```sh
zig build
```

The above will create a `lib/leftpad-z.node` file, which can then be imported in JS:

```js
// lib/main.js

const { leftPad } = require("./leftpad-z.node");

console.log(leftPad("foobar", 10));
console.log(leftPad("foo", 10));
```

```console
$ node ./lib/main.js
    foobar
       foo
```

## Beyond Hello...

Below are a few key concepts for understanding how this library is structured. This is an incomplete overview. Documentation is hard. For a better idea of what's available, you might find it useful to browse the [generated docs](https://kofi-q.github.io/tokota), read through some of the [examples](./examples), and/or make your way through the [tests](https://github.com/search?q=repo%3Akofi-q%2Ftokota+path%3Asrc%2F*%2Ftest.zig&type=code) for more edge-case usage.

### Exporting Modules

As with any JS module, the first point of interaction between a JS client and a Tokota addon is via an `import` (or `require()`) statement. Tokota provides an [`exportModule()`](https://kofi-q.github.io/tokota/#tokota.exportModule) function, intended to be invoked at comptime, which exports JS functions and values corresponding to public declarations found in the exported Zig module.

The following are functionally equivalent, from the perspective of a JS client:

<table>
<tr>
    <th style="text-align: center;">Zig</th>
    <th style="text-align: center;">JS</th>
</tr>
<tr>
<td>

```zig
//! module.zig

const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

const internal = "Not exported";

pub const TUNING_HZ = 440;
pub const Note = enum { A, B, C };

pub fn foo() bool {
    return true;
}

pub const some_namespace = struct {
    pub fn bar() struct { []const u8, bool, u32 } {
        return .{ "one", true, 3 };
    }
};

pub const Encabulator = t.ClassZ("Turbo", struct {
    pub fn constructor(call: t.Call) !t.Object {
        return call.this();
    }

    pub fn encabulate(cb: t.Fn) bool {
        runEncabulation(cb);
        return true;
    }
});
```

</td>
<td>

```js
// module.js







const internal = "Not exported";

export const TUNING_HZ = 440;
export const Note = { A: 0, B: 1, C: 2 };

export function foo() {
  return true;
}

export const some_namespace = {
  bar() {
    return ["one", true, 3];
  },
};

export const Encabulator = class Turbo {
  constructor() {
    // no-op
  }

  encabulate(cb) {
    runEncabulation(cb);
    return true;
  }
};
```

</td>
</tr>
</table>

### Configuring Tokota

As mentioned in the [Versions](#nodejs) section above, the default Node-API version for Tokota addons is [`8`](https://nodejs.org/docs/latest/api/n-api.html#node-api-version-matrix). This setting is used by the Node runtime to determine which version of the APIs to provide to the addon. To build against a different Node-API version - and unlock newer features - add a public [`tokota_options: Options`](https://kofi-q.github.io/tokota/#tokota.Options) declaration to the root source file of the addon module as shown below. This is modeled after the [pattern used by the Zig Standard Library](https://ziglang.org/documentation/master/#toc-Standard-Library-Options) for customizing functionality:

```zig
const tokota = @import("tokota");

pub const tokota_options = tokota.Options{
    .lib_name = "hello-z",
    .napi_version = .v9,
};

comptime {
    tokota.exportModule(@This());
}

pub fn hello() []const u8 {
  return "Hi";
}
```

> [!NOTE]
>
> Usage of API methods that require a higher Node-API version will result in a compile time error. This should help guide version selection, based on which features are needed for the addon:

```zig
//! src/array_buffer/test.zig

const t = @import("tokota");

pub const tokota_options = t.Options{
    .napi_version = .v8,
};

comptime {
    t.exportModule(@This());
}

pub const buffers = struct {
    pub fn fromArrayBuffer(backing_buf: t.ArrayBuffer, len: u32) !t.Buffer {
        return backing_buf.buffer(0, len);
    }
}
```

```console
$ zig build test:node -freference-trace
test:node
└─ run node
   └─ install generated to test.addon.node
      └─ zig build-lib test.addon Debug native 1 errors
src/root.zig:243:9: error:
    [ Node-API Version Mismatch ]
    Expected `.v10` or greater, got `.v8`.
    To use this method, add a `pub const tokota_options: tokota.Options`
    declaration to the root source file and set `napi_version`
    to `.v10` or greater.

    (❓) You may need to build with the `-freference-trace` flag to
         find the relevant source location.

        @compileError(std.fmt.comptimePrint(
        ^~~~~~~~~~~~~
referenced by:
    buffer: src/array_buffer/ArrayBuffer.zig:38:23
    fromArrayBuffer: src/array_buffer/test.zig:240:43
    defineApi__anon_20848: src/object/Object.zig:128:53
    api__anon_20844: src/object/Env.zig:14:22
    infer__anon_20822: src/env.zig:116:34
    defineApi__anon_20153: src/object/Object.zig:131:57
    defineExports__anon_19872: src/root.zig:317:42
    registerModule: src/root.zig:190:42
    comptime: src/root.zig:206:26
    ...
```

### Defining Callbacks

In the example below, `multiply()` serves as the native callback for the equivalent `multiply()` function that is exported in JS. Callbacks are the main communication mechanism between JS code and native addons. They can accept any number of arguments, which will be extracted from the JS call and then validated and converted to the requested Zig type (unless they are of the generic container type, [`Val`](#val), which requires no conversion). [More on that later](#type-conversion).

Callbacks can also optionally accept a special [`Call`](https://kofi-q.github.io/tokota/#tokota.Call) object as the first argument. The `Call` object contains information about the incoming JS function call (including the arguments and the `this` JS object attached to the call) as well as a pointer to the JS runtime [`Env`](#Env) instance.

The following are functionally equivalent implementations of the same callback:

<table>
<tr>
    <th style="text-align: center;">With Built-In Conversion</th>
    <th style="text-align: center;">With Custom Conversion</th>
</tr>
<tr>
<td>

```zig
pub fn multiply(a: u8, b: u8) u16 {
    return a * b;
}











```

</td>
<td>

```zig
pub fn multiply(call: tokota.Call) !tokota.Val {
    const arg1, const arg2 = try call.args(2);

    const a_raw = try arg1.float64(call.env);
    const b_raw = try arg2.float64(call.env);

    // <Number type/range validation goes here...>

    const a: u8 = @intFromFloat(a_raw);
    const b: u8 = @intFromFloat(b_raw);
    const result: u16 = a * b;

    return call.env.uint32(result);
}
```

</td>
</tr>
</table>

The latter pattern provides more flexibility when dealing with with more complex APIs or types, while the former may be more convenient in simpler scenarios and may also open up possibilities for much easier automatic TypeScript type generation, if that's your cup of tea. Take a look at [`Call`](https://kofi-q.github.io/tokota/#tokota.Call) documentation for other argument/call info access patterns.

Note that the `Call` argument can be received alongside other provided arguments as well, when needed:

```zig
const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

pub fn send(call: t.Call, req: t.TypedArray(.u8)) !t.Promise {
    const client = try call.thisUnwrap(*Client) orelse return error.InvalidThis;

    const promise, const deferred = try call.env.promise();
    client.spawnSendTask(req.data, deferred);

    return promise;
}
```

### Env

The [`Env`](https://kofi-q.github.io/tokota/#tokota.Env) type is a wrapper around the Node-API [`napi_env`](https://nodejs.org/docs/latest/api/n-api.html#napi_env) pointer, which represents a JS runtime execution context, or environment for the current process. Wherever [`Env`](https://kofi-q.github.io/tokota/#tokota.Env) is available (usually as part of a [`Call`](https://kofi-q.github.io/tokota/#tokota.Call) in a native callback), we're most likely running code on the main JS thread and have the ability to create JS values, call JS functions and take any other actions that result in JS code getting executed.

```zig
const t = @import("tokota");

comptime {
    t.exportModule(@This());
}

pub fn startsWithFoo(call: t.Call, arg: t.Val) !t.Val {
     // `Env` is required when converting JS values to native ones...
    const str = try arg.string(call.env, 3);

    // ...and vice-versa.
    return call.env.boolean(std.mem.eql(u8, str, "foo"));
}
```

### Val

The [`Val`](https://kofi-q.github.io/tokota/#tokota.Val) type is a generic, opaque handle to a JS value, from which native values can be extracted. It provides an API for interacting with, manipulating, and/or extracting native values from the underlying JS values. JS types can be determined with [`Val.typeOf()`](https://kofi-q.github.io/tokota/#tokota.Val.typeOf) or with any of the more specific `is<Type>()` convenience methods. `Val`s can either be received (via arguments to addon functions), or created via methods on the [`Env`](https://kofi-q.github.io/tokota/#tokota.Env) object.

> [!NOTE]
>
> `Val` handles are only valid for the duration of the scope within  which they are created - usually the scope of an addon callback function. Handles that need to be reference later on an another thread or in another callback must be referenced first (e.g. [`Object.ref()`](https://kofi-q.github.io/tokota/#tokota.Object.ref), [`ArrayBuffer.ref()`](https://kofi-q.github.io/tokota/#tokota.ArrayBuffer.ref)).


### Type Conversion

Tokota has a number of Zig <> JS type conversions built in, for cases where types can be unambiguously and safely converted. For the most up-to-date source of truth, take a look at the following:

- [`Val.to()`](https://kofi-q.github.io/tokota/#tokota.Val.to) for conversion from JS arguments to native callback arguments.
- [`Env.infer()`](https://kofi-q.github.io/tokota/#tokota.Env.infer) for conversion from Zig return types to JS return types (as well as for conversion used in a number of generic API methods).

At a high level, these conversion utilities follow the logic below:

**Constants:**

- `bool` (Zig) <> `boolean` (JS)
- `null` (Zig) <> `undefined` (JS)

**Numbers:**

- `comptime_float` -> `number`
  - One-way conversion only from Zig to JS. Compiler-checked to fit an `f64`.
- `f64` <> `number`
  - This is the most seamless number conversion available. No runtime validation required.
- `f32` -> `number`
  - One-way conversion only from Zig to JS.
- `i1..i53` <> `number`
  - Incoming callback arguments are validated as integer values within the [`safe integer range`](https://mdn.io/Number/isSafeInteger).
- `u1..u53` <> `number`
  - Incoming callback arguments are validated as positive integer values within the [`safe integer range`](https://mdn.io/Number/isSafeInteger).
- `i54..`, `u54..` <> `BigInt`
  - Incoming callback arguments are validated as having an equivalent bit width less than or equal to that of the Zig integer type.
- `comptime_int` -> `number`
  - One-way conversion only from Zig to JS. Comptime-checked to be within the [`safe integer range`](https://mdn.io/Number/isSafeInteger).
- `enum { a, b }` <> `number`
  - Incoming callback arguments are converted to `number` as described above. Enums with integer tag types wider than 53 bits result in compile errors.
- `packed struct(T) { ... }` <> `number`
  - Incoming callback arguments are converted to `number` as described above. Packed structs with integer tag types wider than 53 bits result in compile errors.

**Strings:**

- `[]const u8`, `[]u8`, `[:0]const u8`, `[:0]u8`, `[*:0]const u8`, `*const [N:0]const u8` -> `string`
  - One-way conversion only from Zig to JS. For receiving relatively small string arguments, the stack-allocated `tokota.TinyStr` type is available.

**Arrays/Slices:**

- `[]T`, `[]const T` (and sentinel-terminated variants) -> `Array`
  - One-way conversion only from Zig to JS. For receiving arbitrary-length arrays, the `tokota.Array` type is available.
  - When `T == u8`, the string conversion above takes precedence.
- `[N]T`, `*[N]T`, `[N]const T`, `*[N]const T` (and sentinel-terminated variants) <> `Array`
  - Incoming callback arguments are validated as being JS `Object` types and elements are extracted by index, up to the length of the Zig array and each converted (and validated, if applicable) to the array child type.
  - For `*const [N]const u8`, `*[N]const u8` and sentinel-terminated equivalents, the string conversion above takes precedence.
- `struct { S, T }` <> `Array`
  - Incoming callback arguments are validated as being JS `Object` types and elements are extracted by index, up to the length of the Zig tuple and each converted (and validated, if applicable) to the corresponding tuple element type.

**Objects:**

- `struct { foo: S, bar: T }` <> `Object`
  - Incoming callback arguments are validated as being JS `Object` types and properties are extracted by the corresponding Zig struct field name, converted (and validated, if applicable) to the corresponding struct field type.

**Types:**

`enum` and `struct` type declarations can also be returned from native callbacks and/or exported from native modules.

- `enum { a, b }` -> `Object`
  - Converted to a JS `Object` with properties corresponding to the fields and values of the Zig `enum`. These can then be further typed via TypeScript to provide JS clients with a semblance of type-safe enums.
- `struct { pub fn foo() void {} }` -> `Object`
  - Converted to a JS `Object` interface with methods mapped to the Zig struct `fn` declarations.
  - Any non-`fn` declarations are converted to value properties on the `Object`, but will have no link to the original Zig value (e.g. a `pub var foo: u32` decl will be exported, but changes to `foo` will not be reflected in the JS `Object`).
  - Zig struct fields are ignored. To convert to an `Object` with properties matching struct fields, return an instance of the struct instead.


#### Custom Conversion

For more flexibility when converting complex types like structs and types with no supported inferred conversion, like unions, custom conversion functions can be added to the type to enable receiving it as an argument and/or returning it from a native callback function. See [examples/custom_arg](./examples/custom_arg/main.zig) for an example.

For argument conversion from JS to a custom type, include the following method in the type definition:
```zig
pub fn fromJs(env: tokota.Env, val: tokota.Val) !T;
```

For return value conversion from a custom type to JS, include the following method in the type definition:
```zig
pub fn toJs(self: T, env: tokota.Env) tokota.Val;
```

## License

[MIT](./LICENSE)
