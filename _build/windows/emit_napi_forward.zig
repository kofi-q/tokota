//! Emits a Windows Node-API forwarder Zig source file.
//!
//! The generated forwarder defines local `napi_*` / `node_api_*` symbols that
//! lazily resolve to runtime-provided implementations via `GetProcAddress`.

const std = @import("std");

const FnDef = struct {
    name: []const u8,
    params: []const u8,
    ret: []const u8,
    args: []const []const u8,
};

const src_paths = [_][]const u8{
    "src/napi.zig",
    "src/array/napi.zig",
    "src/array_buffer/napi.zig",
    "src/async/napi.zig",
    "src/date/napi.zig",
    "src/error/napi.zig",
    "src/function/napi.zig",
    "src/global/napi.zig",
    "src/heap/napi.zig",
    "src/lifetime/napi.zig",
    "src/number/napi.zig",
    "src/object/napi.zig",
    "src/string/napi.zig",
};

pub fn main() !void {
    try emit();
}

pub fn emit() !void {
    const allo = std.heap.smp_allocator;

    var io_threaded = std.Io.Threaded.init(allo, .{ .environ = .empty });
    defer io_threaded.deinit();

    const io = io_threaded.ioBasic();

    var defs = try std.ArrayList(FnDef).initCapacity(allo, 0);
    defer {
        for (defs.items) |def| {
            allo.free(def.name);
            allo.free(def.params);
            allo.free(def.ret);

            for (def.args) |arg| allo.free(arg);
            allo.free(def.args);
        }
        defs.deinit(allo);
    }

    for (src_paths) |path| {
        const src = try std.Io.Dir.cwd()
            .readFileAlloc(io, path, allo, .limited(512 * 1024));
        defer allo.free(src);

        try parseExternFns(allo, src, &defs);
    }

    var buf: [2048]u8 = undefined;
    var std_out = std.Io.File.stdout().writer(io, &buf);

    try emitHeader(&std_out.interface);
    try emitSymbolsStruct(&std_out.interface, defs.items);
    try emitWrappers(&std_out.interface, defs.items);

    try std_out.interface.flush();
}

fn emitHeader(w: *std.Io.Writer) !void {
    try w.writeAll(
        \\const std = @import("std");
        \\const t = @import("tokota");
        \\const n = t.napi;
        \\
        \\const AnyPtr = t.AnyPtr;
        \\const AnyPtrConst = t.AnyPtrConst;
        \\const ArrayType = t.ArrayType;
        \\const AsyncComplete = n.AsyncComplete;
        \\const AsyncContext = n.AsyncContext;
        \\const AsyncExecute = n.AsyncExecute;
        \\const AsyncHook = n.cleanup.AsyncHook;
        \\const AsyncWorker = n.AsyncWorker;
        \\const CallInfo = n.CallInfo;
        \\const CallMode = t.threadsafe.CallMode;
        \\const Callback = n.Callback;
        \\const CallbackScope = n.CallbackScope;
        \\const Cb = n.cleanup.Cb;
        \\const CbAsync = n.cleanup.CbAsync;
        \\const Deferred = t.Deferred;
        \\const Env = t.Env;
        \\const ErrorInfo = t.ErrorInfo;
        \\const FinalizeCb = n.FinalizeCb;
        \\const HandleScope = n.HandleScope;
        \\const HandleScopeEscapable = n.HandleScopeEscapable;
        \\const KeyCollectionMode = t.enums.KeyCollectionMode;
        \\const KeyConversion = t.enums.KeyConversion;
        \\const KeyFilter = t.enums.KeyFilter;
        \\const NodeVersion = t.NodeVersion;
        \\const Object = t.Object;
        \\const Property = t.Property;
        \\const Ref = n.Ref;
        \\const ReleaseMode = t.threadsafe.ReleaseMode;
        \\const Status = n.Status;
        \\const ThreadsafeFn = n.ThreadsafeFn;
        \\const ThreadsafeFnProxy = n.ThreadsafeFnProxy;
        \\const UvLoop = n.UvLoop;
        \\const Val = t.Val;
        \\const ValType = t.ValType;
        \\const cleanup = n.cleanup;
        \\const tsfn = t.threadsafe;
        \\
        \\const HMODULE = ?*anyopaque;
        \\extern "kernel32" fn GetModuleHandleA(name: ?[*:0]const u8) callconv(.winapi) HMODULE;
        \\extern "kernel32" fn GetProcAddress(module: HMODULE, proc: [*:0]const u8) callconv(.winapi) ?*anyopaque;
        \\
        \\var symbols_lock: std.Thread.Mutex = .{};
        \\
        \\fn hostModule() HMODULE {
        \\    if (GetModuleHandleA("libnode.dll")) |module| return module;
        \\    if (GetModuleHandleA(null)) |module| return module;
        \\    @panic("Failed to obtain host module handle");
        \\}
        \\
        \\fn lookup(comptime Fn: type, module: HMODULE, comptime symbol: [*:0]const u8) *const Fn {
        \\    const proc = GetProcAddress(module, symbol) orelse std.debug.panic(
        \\        "Missing required Node-API symbol: {s}",
        \\        .{symbol},
        \\    );
        \\    return @ptrCast(proc);
        \\}
        \\
        \\fn resolve(
        \\    comptime Fn: type,
        \\    comptime symbol: [*:0]const u8,
        \\    slot: *?*const Fn,
        \\) *const Fn {
        \\    if (slot.*) |ptr| return ptr;
        \\
        \\    symbols_lock.lock();
        \\    defer symbols_lock.unlock();
        \\
        \\    if (slot.*) |ptr| return ptr;
        \\
        \\    const ptr = lookup(Fn, hostModule(), symbol);
        \\    slot.* = ptr;
        \\    return ptr;
        \\}
        \\
    );
}

fn emitSymbolsStruct(w: *std.Io.Writer, defs: []const FnDef) !void {
    try w.writeAll(
        \\const symbols = struct {
        \\
    );

    for (defs) |def| try w.print(
        \\    var {s}: ?*const @TypeOf(n.{s}) = null;
        \\
    , .{ def.name, def.name });

    try w.writeAll(
        \\};
        \\
    );
}

fn emitWrappers(w: *std.Io.Writer, defs: []const FnDef) !void {
    for (defs) |def| {
        try w.print("pub export fn {s}(\n", .{def.name});
        try w.writeAll(def.params);
        try w.writeAll("\n) ");
        try w.writeAll(def.ret);
        try w.writeAll(" {\n");

        try w.print(
            "    const ptr = resolve(@TypeOf(n.{s}), \"{s}\", &symbols.{s});\n",
            .{ def.name, def.name, def.name },
        );

        if (std.mem.eql(u8, def.ret, "void")) {
            try w.writeAll("    ptr(");
        } else {
            try w.writeAll("    return ptr(");
        }

        for (def.args, 0..) |arg, i| {
            if (i != 0) try w.writeAll(", ");
            try w.writeAll(arg);
        }

        try w.writeAll(
            \\);
            \\}
            \\
        );
    }
}

fn parseExternFns(
    allo: std.mem.Allocator,
    src: []const u8,
    defs: *std.ArrayList(FnDef),
) !void {
    const token = "pub extern fn ";

    var index: usize = 0;
    while (std.mem.indexOfPos(u8, src, index, token)) |start| {
        const name_start = start + token.len;
        const open_paren = std.mem.indexOfScalarPos(u8, src, name_start, '(') orelse
            return error.InvalidExternDecl;

        const name = std.mem.trim(u8, src[name_start..open_paren], " \t\n\r");

        const close_paren = findMatchingParen(src, open_paren) orelse
            return error.InvalidExternDecl;

        const params = std.mem.trim(u8, src[open_paren + 1 .. close_paren], " \t\n\r");

        const semicolon = std.mem.indexOfScalarPos(u8, src, close_paren, ';') orelse
            return error.InvalidExternDecl;

        const ret = std.mem.trim(u8, src[close_paren + 1 .. semicolon], " \t\n\r");
        const args = try parseParamNames(allo, params);

        try defs.append(allo, .{
            .name = try allo.dupe(u8, name),
            .params = try allo.dupe(u8, params),
            .ret = try allo.dupe(u8, ret),
            .args = args,
        });

        index = semicolon + 1;
    }
}

fn parseParamNames(allo: std.mem.Allocator, params: []const u8) ![]const []const u8 {
    var args = try std.ArrayList([]const u8).initCapacity(allo, 0);
    errdefer args.deinit(allo);

    if (params.len == 0) return args.toOwnedSlice(allo);

    var start: usize = 0;
    var depth_paren: usize = 0;
    var depth_bracket: usize = 0;
    var depth_brace: usize = 0;

    for (params, 0..) |c, i| {
        switch (c) {
            '(' => depth_paren += 1,
            ')' => depth_paren -= 1,
            '[' => depth_bracket += 1,
            ']' => depth_bracket -= 1,
            '{' => depth_brace += 1,
            '}' => depth_brace -= 1,
            ',' => if (depth_paren == 0 and depth_bracket == 0 and depth_brace == 0) {
                try appendArgName(allo, &args, params[start..i]);
                start = i + 1;
            },
            else => {},
        }
    }

    try appendArgName(allo, &args, params[start..]);

    return args.toOwnedSlice(allo);
}

fn appendArgName(
    allo: std.mem.Allocator,
    args: *std.ArrayList([]const u8),
    segment_raw: []const u8,
) !void {
    const segment = std.mem.trim(u8, segment_raw, " \t\n\r");
    if (segment.len == 0) return;

    const colon = std.mem.indexOfScalar(u8, segment, ':') orelse
        return error.InvalidExternDecl;

    const name = std.mem.trim(u8, segment[0..colon], " \t\n\r");
    if (name.len == 0) return error.InvalidExternDecl;

    try args.append(allo, try allo.dupe(u8, name));
}

fn findMatchingParen(src: []const u8, open_idx: usize) ?usize {
    var depth: usize = 0;

    var i = open_idx;
    while (i < src.len) : (i += 1) {
        switch (src[i]) {
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if (depth == 0) return i;
            },
            else => {},
        }
    }

    return null;
}
