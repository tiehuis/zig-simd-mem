This is a testing ground for rewriting some std.mem.* functions using
vectorization.

 - `fuzz.zig`: Simplistic fuzzer to verify against a reference C implementation
 - `long.zig`: Opens a file and performs memory scanning and times the result
 - `perf.zig`: Performs a number of measurements against different buffer sizes and
           reports the results as txt or csv (for plotting).
