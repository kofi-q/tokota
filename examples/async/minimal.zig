const ArenaAllocator = @import("std").heap.ArenaAllocator;
const cwd = @import("std").fs.cwd;
const json = @import("std").json;
const smp_allocator = std.heap.smp_allocator;
const std = @import("std");

const t = @import("tokota");

const path_todos = "../_data/todos.json";

pub fn todoTotals(call: t.Call) !t.Promise {
    const runner = try smp_allocator.create(Runner);
    runner.* = .{ .task = undefined };

    // Schedule an async task via Node's worker thread pool and return the
    // resulting `Promise` to the client.
    return call.env.asyncTask(runner, &runner.task);
}

/// Exposes async callbacks required by `Env.asyncTask()` for executing
/// and settling the `Promise`.
const Runner = struct {
    task: t.async.Task(*@This()),

    const Todo = struct { completed: bool };
    const Totals = struct { completed: u32, pending: u32 };

    /// The required `execute()` callback will be invoked from a Node worker
    /// thread. Since the optional `complete()` callback is omitted here, the
    /// return value of the `execute()` method will be used to resolve the
    /// JS promise.
    ///
    /// If an error is returned here, the JS promise will be rejected with a JS
    /// `Error` containing a `code` field set to the error name.
    pub fn execute(_: *Runner) !Totals {
        var arena = std.heap.ArenaAllocator.init(smp_allocator);
        defer arena.deinit();

        const allo = arena.allocator();
        const raw_json = try cwd()
            .readFileAlloc(path_todos, allo, .limited(26 * 1024));

        const todos = try json.parseFromSliceLeaky([]Todo, allo, raw_json, .{
            .ignore_unknown_fields = true,
        });

        var totals = Totals{ .completed = 0, .pending = 0 };
        for (todos) |todo| totals.completed += @intFromBool(todo.completed);

        totals.pending = @intCast(todos.len - totals.completed);

        return totals;
    }

    /// The optional `cleanUp()` callback is invoked from the main JS thread
    /// after all other executor methods have run and after the `Promise` is
    /// settled, but *before* execution is returned to JS. Enables any necessary
    /// cleanup of the async task.
    pub fn cleanUp(self: *Runner, _: t.Env) !void {
        smp_allocator.destroy(self);
    }
};
