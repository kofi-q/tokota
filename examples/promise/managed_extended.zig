const ArenaAllocator = @import("std").heap.ArenaAllocator;
const json = @import("std").json;
const cwd = @import("std").fs.cwd;
const smp_allocator = @import("std").heap.smp_allocator;
const std = @import("std");

const t = @import("tokota");

const path_todos = "../_data/todos.json";

pub fn todosForUser(call: t.Call, user_id: u32, limit: u32) !t.Promise {
    // Schedule an async task via Node's worker thread pool and return the
    // resulting `Promise` to the client.
    return call.env.asyncTaskManaged(smp_allocator, Task, .{ user_id, limit });
}

/// Exposes required and optional async callbacks used by
/// `Env.asyncTaskManaged()` for executing and settling the `Promise`.
const Task = struct {
    const Todo = struct {
        completed: bool,
        id: u32,
        title: [:0]const u8,
        user_id: u32,
    };

    /// The `execute()` callback will be invoked from a Node worker thread with
    /// the arguments given to `Env.asyncTaskManaged()`.
    ///
    /// When done, the `complete()` callback will be invoked from the main
    /// thread with the result of the `execute()` callback.
    pub fn execute(arena: *ArenaAllocator, user_id: u32, limit: usize) ![]Todo {

        // Return errors to trigger promise rejection. See `errConvert()` for
        // more on how to convert error codes to promise rejection values.
        if (user_id == 13) return error.UnluckyNumber;

        // An arena allocator, derived from the allocator passed to
        // `Env.asyncTaskManaged()`, is provided for heap allocations that may
        // be necessary for the task. It is reset once the `Promise` is settled.
        const allo = arena.allocator();
        const raw_json = try cwd().readFileAlloc(allo, path_todos, 26 * 1024);
        const todos = try json.parseFromSliceLeaky([]Todo, allo, raw_json, .{});

        var len_filtered: usize = 0;
        for (0..todos.len) |idx| {
            if (todos[idx].user_id != user_id) continue;

            const elem = todos[len_filtered];
            todos[len_filtered] = todos[idx];
            todos[idx] = elem;

            len_filtered += 1;
            if (len_filtered >= limit) {
                break;
            }
        }

        return todos[0..len_filtered];
    }

    /// The optional `complete()` callback is invoked from the main thread with
    /// the result of the `execute()` callback. Work done in this callback
    /// should be minimal, to avoid blocking the main thread for too long.
    ///
    /// The `Promise` is resolved with the result of this callback. Returned
    /// errors will be converted into `Promise` rejections.
    ///
    /// In some cases, it may be necessary to convert the result into an
    /// appropriate JS value. For convenience, tokota has built-in type
    /// conversion for simple Zig types, so this `[]Todo` can be returned as is.
    pub fn complete(_: t.Env, todos: []Todo) ![]Todo {
        return todos;
    }

    /// The optional `errConvert()` callback is invoked from the main thread if
    /// an error is returned from the `execute()` or `complete()` callbacks.
    /// It's responsible for converting a Zig `error` into a JS `Promise`
    /// rejection value.
    pub fn errConvert(env: t.Env, err: anyerror) !t.Val {
        return switch (err) {
            error.UnluckyNumber => env.err("Invalid user ID!", err),
            else => err,
        };
    }
};
