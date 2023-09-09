const std = @import("std");

const c = @cImport({
    @cInclude("string.h");
});

const max_memory_size = 512 * 1024 * 1024 + (std.mem.page_size) + 1;

const output_csv = false;

var allocator = std.heap.page_allocator;
var memory: []u8 = undefined;
var random: std.rand.Random = undefined;

pub fn main() anyerror!void {
    memory = try allocator.alloc(u8, max_memory_size);
    @memset(memory, 0xaa);

    var seed: [8]u8 = undefined;
    try std.os.getrandom(&seed);

    var prng = std.rand.DefaultPrng.init(@bitCast(seed));
    random = prng.random();

    std.debug.print("time,std.indexOfSentinel,vector.indexOfSentinel,glibc strlen,vector.indexOfScalar,memchr\n", .{});

    // 1..256
    // 256..4096 in steps of 16
    // 4096..512000 in steps of 4096

    if (true) {
        for (1..256) |i| {
            try measure(i, 10000);
        }
    }

    if (true) {
        var i: usize = 256;
        while (i < 4096) : (i += 16) {
            try measure(i, 1000);
        }
    }

    if (true) {
        var i: usize = 4096;
        while (i < 1024 * 1024) : (i += 4096) {
            try measure(i, 10);
        }
    }

    if (true) {
        var i: usize = 1024 * 1024;
        while (i < 512 * 1024 * 1024) : (i += 1024 * 1024) {
            try measure(i, 1);
        }
    }
}

fn measure(buf_len: usize, iterations: usize) !void {
    var t = try std.time.Timer.start();

    // Random start point somewhere in page to test possible unaligned cases.
    // Can use a fixed value here if wanted for testing.
    const offset = random.uintLessThan(usize, std.mem.page_size);

    memory[offset + buf_len] = 0;

    var c_check: usize = 0;
    var c_time: usize = 0;

    var z_check: usize = 0;
    var z_time: usize = 0;

    var zo_check: usize = 0;
    var zo_time: usize = 0;

    var mz_check: usize = 0;
    var mz_time: usize = 0;

    var mc_check: usize = 0;
    var mc_time: usize = 0;

    {
        t.reset();
        for (0..iterations) |_| {
            zo_check += std.mem.indexOfSentinel(u8, 0, @ptrCast(memory.ptr + offset));
        }
        zo_time = t.read();
    }

    {
        t.reset();
        for (0..iterations) |_| {
            z_check += @import("index.zig").vectorized_indexOfSentinel(u8, 0, @ptrCast(memory.ptr + offset));
        }
        z_time = t.read();
    }

    {
        t.reset();
        for (0..iterations) |_| {
            c_check += c.strlen(@ptrCast(memory.ptr + offset));
        }
        c_time = t.read();
    }

    {
        t.reset();
        for (0..iterations) |_| {
            mz_check += @import("index.zig").vectorized_indexOfScalarPos(u8, memory[0 .. buf_len + offset + 1], offset, 0).?;
        }
        mz_time = t.read();
    }

    {
        t.reset();
        for (0..iterations) |_| {
            mc_check += @intFromPtr(c.memchr(@ptrCast(memory.ptr + offset), 0, buf_len + 1));
        }
        mc_time = t.read();
    }

    if (output_csv) {
        std.debug.print("{},{},{},{},{},{}\n", .{
            buf_len,
            zo_time / iterations,
            z_time / iterations,
            c_time / iterations,
            mz_time / iterations,
            mc_time / iterations,
        });
    } else {
        std.debug.print(" {:>9.2}: {d:<10.2} {d:<10.2} {d:<10.2} {d:<10.2} {d:<10.2}\n", .{
            std.fmt.fmtIntSizeBin(buf_len),
            std.fmt.fmtDuration(zo_time / iterations),
            std.fmt.fmtDuration(z_time / iterations),
            std.fmt.fmtDuration(c_time / iterations),

            std.fmt.fmtDuration(mz_time / iterations),
            std.fmt.fmtDuration(mc_time / iterations),
        });
    }

    std.mem.doNotOptimizeAway(zo_check +% z_check +% c_check +% mz_check +% mc_check);

    memory[offset + buf_len] = 0xaa;
}

const Ticker = struct {
    start: u64,

    pub fn start() Ticker {
        return .{ .start = cpuid_rdtsc() };
    }

    pub fn end(self: Ticker) u64 {
        return rdtscp() - self.start;
    }

    fn cpuid_rdtsc() u64 {
        var lo: u64 = undefined;
        var hi: u64 = undefined;

        asm volatile (
            \\cpuid
            \\rdtsc
            : [lo] "={rax}" (lo),
              [hi] "={rdx}" (hi),
            :
            : "{rax}", "{rbx}", "{rcx}", "{rdx}"
        );

        return (hi << 32) | lo;
    }

    fn rdtscp() u64 {
        var lo: u64 = undefined;
        var hi: u64 = undefined;

        asm volatile (
            \\rdtscp
            \\movq %%rax, %[lo]
            \\movq %%rdx, %[hi]
            \\cpuid
            : [lo] "=m" (lo),
              [hi] "=m" (hi),
            :
            : "{rax}", "{rbx}", "{rcx}", "{rdx}"
        );

        return (hi << 32) | lo;
    }
};
