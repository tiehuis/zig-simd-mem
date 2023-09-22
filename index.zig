const std = @import("std");

pub fn vectorized_indexOfScalarPos(comptime T: type, slice: []const T, start_index: usize, value: T) ?usize {
    var i: usize = start_index;

    if (!@inComptime() and (@typeInfo(T) == .Int or @typeInfo(T) == .Float) and std.math.isPowerOfTwo(@bitSizeOf(T))) {
        if (comptime std.simd.suggestVectorSize(T)) |block_len| {
            // For Intel Nehalem (2009) and AMD Bulldozer (2012) or later, unaligned loads on aligned data result
            // in the same execution as aligned loads. We ignore older arch's here and don't bother pre-aligning.
            //
            // Use `comptime std.simd.suggestVectorSize(T)` to get the same alignment as used in this function
            // however this usually isn't necessary unless your arch has a performance penalty due to this.
            //
            // Note: This may differ for other arch's. e.g. arm does not like loads across cache lines (costs
            // a cycle) so we may want an explicit alignment prologue for these.

            // Unrolling here is ~10% improvement. We can then do one bounds check every 2 blocks
            // instead of one which adds up.
            const Block = @Vector(block_len, T);
            if (i + 2 * block_len < slice.len) {
                const mask: Block = @splat(value);
                while (true) {
                    inline for (0..2) |_| {
                        const block: Block = slice[i..][0..block_len].*;
                        const matches = block == mask;
                        if (@reduce(.Or, matches)) {
                            return i + std.simd.firstTrue(matches).?;
                        }
                        i += block_len;
                    }
                    if (i + 2 * block_len >= slice.len) break;
                }
            }

            // {block_len, block_len / 2} check
            inline for (0..2) |j| {
                const block_x_len = block_len / (1 << j);
                comptime if (block_x_len < 4) break;

                const BlockX = @Vector(block_x_len, T);
                if (i + block_x_len < slice.len) {
                    const mask: BlockX = @splat(value);
                    const block: BlockX = slice[i..][0..block_x_len].*;
                    const matches = block == mask;
                    if (@reduce(.Or, matches)) {
                        return i + std.simd.firstTrue(matches).?;
                    }
                    i += block_x_len;
                }
            }
        }
    }

    while (i < slice.len) : (i += 1) {
        if (slice[i] == value) return i;
    }
    return null;
}

pub fn vectorized_indexOfSentinel(comptime T: type, comptime sentinel: T, p: [*:sentinel]const T) usize {
    var i: usize = 0;

    if (!@inComptime() and (@typeInfo(T) == .Int or @typeInfo(T) == .Float) and std.math.isPowerOfTwo(@bitSizeOf(T))) {
        switch (@import("builtin").cpu.arch) {
            // The below branch assumes that reading past the end of the buffer is valid, as long
            // as we don't read into a new page. This should be the case for most architectures
            // which use paged memory, however should be confirmed before adding a new arch below.
            .aarch64, .x86, .x86_64 => if (comptime std.simd.suggestVectorSize(T)) |block_len| {
                comptime std.debug.assert(std.mem.page_size % block_len == 0);
                const Block = @Vector(block_len, T);
                const mask: Block = @splat(sentinel);

                // First block may be unaligned
                const start_addr = @intFromPtr(&p[i]);
                const offset_in_page = start_addr & (std.mem.page_size - 1);
                if (offset_in_page < std.mem.page_size - block_len) {
                    // Will not read past the end of a page, full block.
                    const block: Block = p[i..][0..block_len].*;
                    const matches = block == mask;
                    if (@reduce(.Or, matches)) {
                        return i + std.simd.firstTrue(matches).?;
                    }

                    i += (std.mem.alignForward(usize, start_addr, @alignOf(Block)) - start_addr) / @sizeOf(T);
                } else {
                    // Would read over a page boundary. Per-byte at a time until aligned or found.
                    // 0.39% chance this branch is taken for 4K pages at 16b block length.
                    //
                    // An alternate strategy is to do read a full block (the last in the page) and
                    // mask the entries before the pointer.
                    while ((@intFromPtr(&p[i]) & (@alignOf(Block) - 1)) != 0) : (i += 1) {
                        if (p[i] == sentinel) return i;
                    }
                }

                std.debug.assert(std.mem.isAligned(@intFromPtr(&p[i]), @alignOf(Block)));
                while (true) {
                    const block: *const Block = @ptrCast(@alignCast(p[i..][0..block_len]));
                    const matches = block.* == mask;
                    if (@reduce(.Or, matches)) {
                        return i + std.simd.firstTrue(matches).?;
                    }
                    i += block_len;
                }
            },
            else => {},
        }
    }

    while (p[i] != sentinel) {
        i += 1;
    }
    return i;
}

pub fn std_indexOfScalarPos(comptime T: type, slice: []const T, start_index: usize, value: T) ?usize {
    var i: usize = start_index;
    while (i < slice.len) : (i += 1) {
        if (slice[i] == value) return i;
    }
    return null;
}

pub fn std_indexOfSentinel(comptime Elem: type, comptime sentinel: Elem, ptr: [*:sentinel]const Elem) usize {
    var i: usize = 0;
    while (ptr[i] != sentinel) {
        i += 1;
    }
    return i;
}

const Ty = u8;
export fn _std_indexOfSentinel(p: [*:0]const Ty) usize {
    return std_indexOfSentinel(Ty, 0, p);
}
export fn _std_indexOfScalarPos(p: [*]const Ty, len: usize, value: Ty) usize {
    return std_indexOfScalarPos(Ty, p[0..len], 0, value).?;
}

export fn _vectorized_indexOfSentinel(p: [*:0]const Ty) usize {
    return vectorized_indexOfSentinel(Ty, 0, p);
}
export fn _vectorized_indexOfScalarPos(p: [*]const Ty, len: usize, value: Ty) usize {
    return vectorized_indexOfScalarPos(Ty, p[0..len], 0, value).?;
}
