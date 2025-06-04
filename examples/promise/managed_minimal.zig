const ArenaAllocator = @import("std").heap.ArenaAllocator;
const json = @import("std").json;
const std = @import("std");
const cwd = @import("std").fs.cwd;

const t = @import("tokota");

const path_todos = "../_data/todos.json";

pub fn todoTotals(call: t.Call) !t.Promise {
    // Schedule an async task via Node's worker thread pool and return the
    // resulting `Promise` to the client.
    return call.env.asyncTaskManaged(std.heap.smp_allocator, Task, .{});
}

/// Exposes async callbacks required by `Env.asyncTaskManaged()` for executing
/// and settling the `Promise`.
const Task = struct {
    const Todo = struct { completed: bool };
    const Totals = struct { completed: u32, pending: u32 };

    /// The `execute()` callback will be invoked from a Node worker thread with
    /// the arguments given to `Env.asyncTaskManaged()`, if any.
    pub fn execute(arena: *ArenaAllocator) !Totals {

        // An arena allocator, derived from the allocator passed to
        // `Env.asyncTaskManaged()`, is provided for heap allocations that may be
        // necessary for the task. It is reset once the `Promise` is settled.
        const allo = arena.allocator();
        const raw_json = try cwd().readFileAlloc(allo, path_todos, 26 * 1024);

        const todos = try json.parseFromSliceLeaky([]Todo, allo, raw_json, .{
            .ignore_unknown_fields = true,
        });

        var totals = Totals{ .completed = 0, .pending = 0 };
        for (todos) |todo| totals.completed += @intFromBool(todo.completed);

        totals.pending = @intCast(todos.len - totals.completed);

        return totals;
    }
};
