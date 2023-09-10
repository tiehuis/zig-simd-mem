This is a testing ground for rewriting some std.mem.* functions using
vectorization.

 - `fuzz.zig`: Simplistic fuzzer to verify against a reference C implementation
 - `long.zig`: Opens a file and performs memory scanning and times the result
 - `perf.zig`: Performs a number of measurements against different buffer sizes and
           reports the results as txt or csv (for plotting).

# Versions


```
# x86_64
$ zig version
0.12.0-dev.4701+f4c9e19bc
$ ldd --version
ldd (GNU libc) 2.38
```

```
# aarch64
$ zig version
0.12.0-dev.244+f4c9e19bc
# unsure the libc library/version
# Ventura 13.4
```
