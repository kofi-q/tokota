const cwd = @import("std").fs.cwd;
const std = @import("std");
const json = @import("std").json;
const time = @import("std").time;

const t = @import("tokota");

const allo = std.heap.smp_allocator;
const log = std.log.scoped(.todo_stream);

comptime {
    t.exportModule(@This());
}

const Task = struct {
    active: std.atomic.Value(bool),
    on_chunk: t.threadsafe.Fn(*const Chunk),
};

const Todo = struct {
    completed: bool,
    id: u32,
    title: [:0]const u8,
    user_id: u32,
};

const Chunk = union(enum) { err: anyerror, todo: *Todo };

/// Exported JS function. Spawns a background thread which invokes the given
/// callback with a `Todo` object at regular intervals until cancelled.
///
/// Uses a Node-API `ThreadsafeFn` for communication with the main JS thread.
pub fn todoStream(call: t.Call, user_id: u32, on_chunk: t.Fn) !t.Fn {
    const task = try allo.create(Task);
    task.* = .{
        .active = .init(true),
        // Create a threadsafe function from the client-provided JS callback.
        // This will prevent the main JS loop from exiting until the TsFn is
        // released.
        .on_chunk = try on_chunk.threadsafeFn({}, *const Chunk, sendChunk, .{
            .finalizer = .with(task, deinit),
        }),
    };

    const thread = try std.Thread.spawn(.{}, run, .{ user_id, task });
    thread.detach();

    return call.env.functionT(cancel, task);
}

/// Entry point for the background thread.
fn run(user_id: u32, task: *Task) void {
    // Release the `ThreadsafeFn` when the stream is closed, to allow the main
    // JS loop to exit.
    defer task.on_chunk.release(.release) catch |e| {
        log.err("Unable to release async task: {}", .{e});
    };

    log.info("Starting stream...", .{});

    fetchChunks(user_id, task) catch |e| {
        task.on_chunk.call(&.{ .err = e }, .blocking) catch {
            log.err("Unable to report stream error: {}. Exiting...", .{e});
            std.process.exit(1);
        };
    };
}

const path_todos = "../_data/todos.json";

/// Main loop for the background thread, split out for simpler error handling.
fn fetchChunks(user_id: u32, task: *Task) !void {
    const raw_json = try cwd()
        .readFileAlloc(path_todos, allo, .limited(26 * 1024));
    defer allo.free(raw_json);

    var io_threaded = std.Io.Threaded.init(allo);
    defer io_threaded.deinit();
    const io = io_threaded.io();

    const todos = try json.parseFromSlice([]Todo, allo, raw_json, .{});
    defer todos.deinit();

    for (todos.value) |*todo| {
        if (todo.user_id != user_id) {
            continue;
        }

        try io.sleep(.fromMilliseconds(100), .real);
        if (!task.active.load(.acquire)) {
            break;
        }

        // Call the `ThreadsafeFn` any number of times with the previously
        // specified argument type. See `sendChunk()`.
        task.on_chunk.call(&.{ .todo = todo }, .blocking) catch |e| {
            switch (e) {
                t.Err.ThreadsafeFnClosing => break,
                else => return e,
            }
        };
    } else {
        task.on_chunk.call(&.{ .err = error.Done }, .blocking) catch |e| {
            switch (e) {
                t.Err.ThreadsafeFnClosing => {},
                else => return e,
            }
        };
    }
}

/// Handles `ThreadsafeFn` calls, converting the argument to a corresponding
/// function call to the JS callback provided in `todoStream()`.
fn sendChunk(env: t.Env, chunk: *const Chunk, cb: t.Fn) !void {
    _ = switch (chunk.*) {
        .err => |code| try cb.call(.{env.err("Unexpected error", code)}),
        .todo => |todo| try cb.call(.{ {}, todo }),
    };
}

/// Cancels the stream
fn cancel(call: t.CallT(*Task)) void {
    const task = call.data() catch unreachable orelse {
        t.panic("Unable to cancel stream - missing task info!", null);
    };

    log.info("Cancelling stream...", .{});
    task.active.store(false, .release);
}

fn deinit(task: *Task, _: t.Env) !void {
    allo.destroy(task);
}
