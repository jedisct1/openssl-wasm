//! malloc() and friends on top of the Zig WebAssembly allocator.
//!
//! Zig allocators need the size and alignment back when freeing, and C doesn't
//! provide them, so both are stored in a small header right before the pointer
//! handed out to the caller.

const std = @import("std");
const Alignment = std.mem.Alignment;
const libc = @import("libc.zig");
const symbol = libc.symbol;

comptime {
    symbol(&malloc, "malloc");
    symbol(&calloc, "calloc");
    symbol(&realloc, "realloc");
    symbol(&free, "free");
    symbol(&aligned_alloc, "aligned_alloc");
    symbol(&posix_memalign, "posix_memalign");
}

const vtable = std.heap.WasmAllocator.vtable;

/// alignof(max_align_t) on wasm, because of the 128-bit long double.
const min_alignment: Alignment = .@"16";

const Header = extern struct {
    size: usize,
    alignment: usize,

    comptime {
        std.debug.assert(@sizeOf(Header) <= min_alignment.toByteUnits());
    }

    fn of(ptr: [*]u8) *Header {
        return @ptrCast(@alignCast(ptr - @sizeOf(Header)));
    }

    /// The whole block as seen by the underlying allocator.
    fn block(header: *const Header, ptr: [*]u8) []u8 {
        return (ptr - header.alignment)[0 .. header.alignment + header.size];
    }
};

/// Alignments are at least 16 bytes, and the gap in front of the user pointer
/// is exactly one alignment unit, which always leaves room for the header.
fn allocAligned(size: usize, alignment: Alignment) ?[*]u8 {
    const a = alignment.max(min_alignment);
    const pad = a.toByteUnits();
    const total = std.math.add(usize, size, pad) catch return null;
    const base = vtable.alloc(undefined, total, a, 0) orelse return null;
    const ptr = base + pad;
    Header.of(ptr).* = .{ .size = size, .alignment = pad };
    return ptr;
}

fn nomem() ?*anyopaque {
    @branchHint(.cold);
    libc.setErrno(.NOMEM);
    return null;
}

pub fn malloc(size: usize) callconv(.c) ?*anyopaque {
    return allocAligned(size, min_alignment) orelse nomem();
}

fn calloc(n: usize, size: usize) callconv(.c) ?*anyopaque {
    const total = std.math.mul(usize, n, size) catch return nomem();
    const ptr = allocAligned(total, min_alignment) orelse return nomem();
    @memset(ptr[0..total], 0);
    return ptr;
}

pub fn free(opt_ptr: ?*anyopaque) callconv(.c) void {
    const ptr: [*]u8 = @ptrCast(opt_ptr orelse return);
    const header = Header.of(ptr);
    const alignment = Alignment.fromByteUnits(header.alignment);
    vtable.free(undefined, header.block(ptr), alignment, 0);
}

/// Like glibc, a zero size frees the block and returns NULL.
fn realloc(opt_ptr: ?*anyopaque, size: usize) callconv(.c) ?*anyopaque {
    const ptr: [*]u8 = @ptrCast(opt_ptr orelse return malloc(size));
    if (size == 0) {
        free(ptr);
        return null;
    }
    const header = Header.of(ptr);
    const old_size = header.size;
    const pad = header.alignment;
    const alignment = Alignment.fromByteUnits(pad);
    const total = std.math.add(usize, size, pad) catch return nomem();

    if (vtable.remap(undefined, header.block(ptr), alignment, total, 0)) |base| {
        const new_ptr = base + pad;
        Header.of(new_ptr).size = size;
        return new_ptr;
    }
    const new_ptr = allocAligned(size, alignment) orelse return nomem();
    @memcpy(new_ptr[0..@min(size, old_size)], ptr[0..@min(size, old_size)]);
    free(ptr);
    return new_ptr;
}

fn aligned_alloc(alignment: usize, size: usize) callconv(.c) ?*anyopaque {
    if (!std.math.isPowerOfTwo(alignment)) {
        libc.setErrno(.INVAL);
        return null;
    }
    return allocAligned(size, .fromByteUnits(alignment)) orelse nomem();
}

/// Reports errors through the return value and leaves errno alone, as POSIX requires.
fn posix_memalign(out: *?*anyopaque, alignment: usize, size: usize) callconv(.c) c_int {
    if (!std.math.isPowerOfTwo(alignment) or alignment < @sizeOf(*anyopaque)) {
        return @intFromEnum(libc.E.INVAL);
    }
    out.* = allocAligned(size, .fromByteUnits(alignment)) orelse return @intFromEnum(libc.E.NOMEM);
    return 0;
}
