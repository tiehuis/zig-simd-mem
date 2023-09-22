const std = @import("std");

extern fn strlen(ptr: [*c]const u8) usize;
const indexOfSentinel = @import("index.zig").vectorized_indexOfSentinel;

const no_of_pages = 10;
const memory_size = no_of_pages * std.mem.page_size;
const iterations = 1_000_000;

pub fn testType(comptime T: type) !void {
    std.debug.print("{s}\n", .{@typeName(T)});
    var allocator = std.heap.page_allocator;

    const len = memory_size / @sizeOf(T);
    const memory = try allocator.alloc(T, len);
    defer allocator.free(memory);
    @memset(memory, 0xaa);

    var seed: [8]u8 = undefined;
    try std.os.getrandom(&seed);

    var prng = std.rand.DefaultPrng.init(@bitCast(seed));
    const random = prng.random();
    var timer = try std.time.Timer.start();
    var c_time: u64 = 0;
    var z_time: u64 = 0;
    var zc_time: u64 = 0;

    for (1..iterations) |i| {
        if ((i % 100_000) == 0) {
            std.debug.print("{}\n", .{i});
        }

        const beg = random.uintLessThan(usize, len);
        const end = beg + random.uintLessThan(usize, len - beg);
        memory[end] = 0;

        var c_end: usize = 0;
        if (T == u8) {
            timer.reset();
            c_end = strlen(@ptrCast(memory.ptr + beg));
            c_time += timer.read();
        }

        timer.reset();
        const z_end = indexOfSentinel(T, 0, @ptrCast(memory.ptr + beg));
        z_time += timer.read();

        timer.reset();
        const zc_end = std.mem.indexOfSentinel(T, 0, @ptrCast(memory.ptr + beg));
        zc_time += timer.read();

        if (T == u8 and c_end != z_end) {
            std.debug.print("! p={x}, end={}, c={}, zig={}, zig.std={}\n", .{ @intFromPtr(&memory[beg]), end, c_end, z_end, zc_end });
            return error.DidNotMatch;
        } else if (z_end != zc_end) {
            std.debug.print("! p={x}, end={}, zig={}, zig.std={}\n", .{ @intFromPtr(&memory[beg]), end, z_end, zc_end });
            return error.DidNotMatch;
        }

        memory[end] = 0xaa;
    }

    std.debug.print(
        \\memory size: {}
        \\  c:     {} avg
        \\zig:     {} avg
        \\zig.std: {} avg
        \\
    , .{
        std.fmt.fmtIntSizeBin(memory_size),
        std.fmt.fmtDuration(c_time / iterations),
        std.fmt.fmtDuration(z_time / iterations),
        std.fmt.fmtDuration(zc_time / iterations),
    });
}

pub fn main() anyerror!void {
    const ts = [_]type{ u8, u16, u32, u64, u128 };
    inline for (ts) |t| {
        try testType(t);
    }
}
