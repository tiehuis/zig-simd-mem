const std = @import("std");

extern fn strlen(ptr: [*c]const u8) usize;
const indexOfSentinel = @import("index.zig").vectorized_indexOfSentinel;

const no_of_pages = 1_000;
const memory_size = no_of_pages * std.mem.page_size;
const iterations = 1_000_000;

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    const memory = try allocator.alloc(u8, memory_size);
    @memset(memory, 0xaa);

    var seed: [8]u8 = undefined;
    try std.os.getrandom(&seed);

    var prng = std.rand.DefaultPrng.init(@bitCast(seed));
    const random = prng.random();

    var timer = try std.time.Timer.start();
    var c_time: u64 = 0;
    var z_time: u64 = 0;

    for (1..iterations) |i| {
        if ((i % 100_000) == 0) {
            std.debug.print("{}\n", .{i});
        }

        const end = random.uintLessThan(usize, memory_size);
        memory[end] = 0;

        timer.reset();
        const c_end = strlen(@ptrCast(memory.ptr));
        c_time += timer.read();

        timer.reset();
        const z_end = indexOfSentinel(u8, 0, @ptrCast(memory.ptr));
        z_time += timer.read();

        if (c_end != z_end) {
            std.debug.print("! end={}, c={}, zig={}\n", .{ end, c_end, z_end });
            return error.DidNotMatch;
        }

        memory[end] = 0xaa;
    }

    std.debug.print(
        \\memory size: {}
        \\  c: {} avg
        \\zig: {} avg
        \\
    , .{
        std.fmt.fmtIntSizeBin(memory_size),
        std.fmt.fmtDuration(c_time / iterations),
        std.fmt.fmtDuration(z_time / iterations),
    });
}
