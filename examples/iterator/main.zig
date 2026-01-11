const std = @import("std");
const json = @import("std").json;

const t = @import("tokota");

pub const tokota_options = t.Options{
    .lib_name = "example-iterator",
    .napi_version = .v8,
};

var allo_global = std.heap.smp_allocator;

comptime {
    t.exportModule(@This());
}

/// Exported JS function. Returns an `Object` satisfying the JS `Iterable`
/// interface.
pub fn todoIterator(call: t.Call, user_id: u32) !t.Object {
    // Retrieve the JS `Symbol.iterator` symbol from the global scope.
    const symbol_iterator = try call.env.run("Symbol.iterator");

    // Define a JS object with a `[Symbol.iterator]` method and attach the
    // native iterator data for later use.
    const iterator = try Iterator.init(user_id);
    const iterable = try call.env.objectDefine(&.{
        // Data bound to exported functions will be available to Zig code when
        // they are called from JS. See usage of `Call.data()` below in `start`.
        .methodT(symbol_iterator, Iterator.start, iterator, .{}),
    });

    // Make sure the iterator is de-allocated when the JS object is GC'd.
    _ = try iterable.addFinalizer(.with(iterator, Iterator.deinit));

    return iterable;
}

const Iterator = struct {
    arena: *std.heap.ArenaAllocator,
    idx: usize,
    todos: []Todo,
    user_id: u32,

    const Api = t.Api(*Iterator, Iterator);
    const Call = t.CallT(*Iterator);
    const Result = struct { done: bool, value: ?*const Todo };

    /// Implements the `[Symbol.iterator]() method of the JS
    /// [`Iterable` protocol](https://mdn.io/iteration_protocols).
    fn start(call: Call) !Iterator.Api {
        // Extract the iterator data attached in `todoIterator()`.
        const it = try call.data() orelse return error.MissingFnData;

        const allo = it.arena.allocator();

        var io_threaded = std.Io.Threaded.init(allo, .{ .environ = .empty });
        defer io_threaded.deinit();
        const io = io_threaded.io();

        const path_todos = "../_data/todos.json";
        const raw_json = try std.Io.Dir.cwd()
            .readFileAlloc(io, path_todos, allo, .limited(26 * 1024));

        it.todos = try json.parseFromSliceLeaky([]Todo, allo, raw_json, .{});

        // Attach the iterator data to the API for later use in the `next()` fn.
        return .{ .data = it };
    }

    /// Implements the `next()` method of the JS
    /// [`Iterator` protocol](https://mdn.io/iteration_protocols).
    pub fn next(call: Call) !Result {
        // Extract the iterator data that was attached in `start()` above.
        const self = try call.data() orelse return error.MissingFnData;

        while (self.idx < self.todos.len) {
            defer self.idx += 1;

            if (self.todos[self.idx].user_id != self.user_id) continue;

            return .{
                .done = false,
                .value = &self.todos[self.idx],
            };
        }

        return .{
            .done = true,
            .value = null,
        };
    }

    fn init(user_id: u32) !*Iterator {
        var arena = try allo_global.create(std.heap.ArenaAllocator);
        errdefer allo_global.destroy(arena);

        arena.* = std.heap.ArenaAllocator.init(allo_global);
        errdefer arena.deinit();

        const iterator = try arena.allocator().create(Iterator);
        iterator.* = .{
            .arena = arena,
            .idx = 0,
            .todos = &.{},
            .user_id = user_id,
        };

        return iterator;
    }

    fn deinit(self: *Iterator, _: t.Env) !void {
        const arena = self.arena;
        arena.deinit();
        allo_global.destroy(arena);
    }
};

const Todo = struct {
    completed: bool,
    id: u32,
    title: [:0]const u8,
    user_id: u32,
};
