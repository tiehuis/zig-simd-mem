const std = @import("std");

const scan = @import("index.zig");

const c = @cImport({
    @cInclude("string.h");
});

pub fn main() anyerror!void {
    var args = try std.process.argsAlloc(std.heap.c_allocator);
    var file = try std.fs.cwd().openFileZ(args[args.len - 1], .{ .mode = .read_only });
    var contents = try std.heap.c_allocator.dupeZ(u8, try file.readToEndAlloc(std.heap.c_allocator, std.math.maxInt(usize)));

    var time = try std.time.Timer.start();

    time.reset();
    {
        const end = std.mem.indexOfSentinel(u8, 0, contents);
        var slice = contents[0..end];
        std.mem.doNotOptimizeAway(&slice);
    }
    const z_ios_std_time = time.read();

    time.reset();
    {
        const end = scan.vectorized_indexOfSentinel(u8, 0, contents);
        var slice = contents[0..end];
        std.mem.doNotOptimizeAway(&slice);
    }
    const z_ios_v_time = time.read();

    time.reset();
    {
        var len = c.strlen(contents);
        std.mem.doNotOptimizeAway(&len);
    }
    const c_strlen_time = time.read();

    ////

    time.reset();
    {
        const end = std.mem.indexOfScalarPos(u8, contents[0 .. contents.len + 1], 0, 0);
        std.mem.doNotOptimizeAway(&end);
    }
    const z_iosp_std_time = time.read();

    time.reset();
    {
        const end = scan.vectorized_indexOfScalarPos(u8, contents[0 .. contents.len + 1], 0, 0);
        std.mem.doNotOptimizeAway(&end);
    }
    const z_iosp_v_time = time.read();

    time.reset();
    {
        const end = c.memchr(contents.ptr, 0, contents.len);
        std.mem.doNotOptimizeAway(&end);
    }
    const c_memchr = time.read();

    std.debug.print(
        \\Reading {s} ({any})
        \\
        \\    std.mem.sliceTo: {any}
        \\ vectorized.sliceTo: {any}
        \\             strlen: {any}
        \\
        \\  std.indexOfScalar: {any}
        \\    v.indexOfScalar: {any}
        \\             memchr: {any}
        \\
    ,
        .{
            args[args.len - 1],
            std.fmt.fmtIntSizeBin(contents.len),
            std.fmt.fmtDuration(z_ios_std_time),
            std.fmt.fmtDuration(z_ios_v_time),
            std.fmt.fmtDuration(c_strlen_time),

            std.fmt.fmtDuration(z_iosp_std_time),
            std.fmt.fmtDuration(z_iosp_v_time),
            std.fmt.fmtDuration(c_memchr),
        },
    );
}
