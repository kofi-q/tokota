# Size/Performance Overhead Benchmarks

These aren't intended as performance benchmarks - just an aid in figuring out how much overhead is being introduced by the provided abstractions over the Node-API. Mainly concerned about keeping track of binary size bloat from all the comptime generics being used and any potential performance costs from the callback wrappers and inferred type conversion. The latter shouldn't matter in most cases - only relevant in extreme situations (e.g. where addon methods are called in a tight loop).

To list available benchmarks:
```sh
zig build -l | grep bench
```

To run a benchmark:
```sh
zig build bench:hello
```
