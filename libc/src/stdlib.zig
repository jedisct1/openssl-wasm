const std = @import("std");
const libc = @import("libc.zig");
const symbol = libc.symbol;
const isspace = @import("ctype.zig").isspace;

comptime {
    symbol(&strtol, "strtol");
    symbol(&strtoul, "strtoul");
    symbol(&strtoll, "strtoll");
    symbol(&strtoull, "strtoull");
    symbol(&strtoll, "strtoimax");
    symbol(&strtoull, "strtoumax");
    symbol(&atoi, "atoi");
    symbol(&atol, "atol");
    symbol(&atoll, "atoll");
    symbol(&abs, "abs");
    symbol(&labs, "labs");
    symbol(&llabs, "llabs");
    symbol(&llabs, "imaxabs");
    symbol(&div, "div");
    symbol(&ldiv, "ldiv");
    symbol(&lldiv, "lldiv");
    symbol(&qsort, "qsort");
    symbol(&bsearch, "bsearch");
    symbol(&getenv, "getenv");
    symbol(&getenv, "secure_getenv");
}

fn digitValue(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'z' => c - 'a' + 10,
        'A'...'Z' => c - 'A' + 10,
        else => 255,
    };
}

/// Shared by the whole strto*() family and by sscanf().
/// At most `max_len` bytes are looked at, which is how sscanf() honors field widths.
/// Out of range values saturate and set ERANGE, like C requires.
/// For unsigned types, a minus sign negates the result modulo 2^N.
/// Returns the value and how many bytes were consumed, zero if there were no digits.
pub fn parseInt(comptime T: type, s: [*:0]const u8, max_len: usize, base_arg: c_int) struct { T, usize } {
    const U = @Int(.unsigned, @bitSizeOf(T));
    const signed = @typeInfo(T).int.signedness == .signed;

    if (base_arg < 0 or base_arg == 1 or base_arg > 36) {
        libc.setErrno(.INVAL);
        return .{ 0, 0 };
    }

    const at = struct {
        fn at(str: [*:0]const u8, max: usize, i: usize) u8 {
            return if (i < max) str[i] else 0;
        }
    }.at;

    var i: usize = 0;
    while (isspace(at(s, max_len, i)) != 0) i += 1;
    var negative = false;
    if (at(s, max_len, i) == '-' or at(s, max_len, i) == '+') {
        negative = at(s, max_len, i) == '-';
        i += 1;
    }

    var base: U = @intCast(base_arg);
    if ((base == 0 or base == 16) and at(s, max_len, i) == '0' and
        (at(s, max_len, i + 1) | 0x20) == 'x' and digitValue(at(s, max_len, i + 2)) < 16)
    {
        i += 2;
        base = 16;
    } else if (base == 0) {
        base = if (at(s, max_len, i) == '0') 8 else 10;
    }

    const limit: U = if (signed and negative) @as(U, std.math.maxInt(T)) + 1 else std.math.maxInt(T);
    var acc: U = 0;
    var any_digit = false;
    var overflow = false;
    while (digitValue(at(s, max_len, i)) < base) : (i += 1) {
        any_digit = true;
        const mul = @mulWithOverflow(acc, base);
        const sum = @addWithOverflow(mul[0], digitValue(at(s, max_len, i)));
        if (mul[1] != 0 or sum[1] != 0 or sum[0] > limit) {
            overflow = true;
        } else if (!overflow) {
            acc = sum[0];
        }
    }

    if (!any_digit) return .{ 0, 0 };
    if (overflow) {
        libc.setErrno(.RANGE);
        return .{ if (signed and negative) std.math.minInt(T) else std.math.maxInt(T), i };
    }
    return .{ @bitCast(if (negative) 0 -% acc else acc), i };
}

fn strto(comptime T: type, s: [*:0]const u8, end: ?*[*:0]const u8, base: c_int) T {
    const value, const len = parseInt(T, s, std.math.maxInt(usize), base);
    if (end) |e| e.* = s + len;
    return value;
}

fn strtol(s: [*:0]const u8, end: ?*[*:0]const u8, base: c_int) callconv(.c) c_long {
    return strto(c_long, s, end, base);
}

fn strtoul(s: [*:0]const u8, end: ?*[*:0]const u8, base: c_int) callconv(.c) c_ulong {
    return strto(c_ulong, s, end, base);
}

fn strtoll(s: [*:0]const u8, end: ?*[*:0]const u8, base: c_int) callconv(.c) c_longlong {
    return strto(c_longlong, s, end, base);
}

fn strtoull(s: [*:0]const u8, end: ?*[*:0]const u8, base: c_int) callconv(.c) c_ulonglong {
    return strto(c_ulonglong, s, end, base);
}

fn atoi(s: [*:0]const u8) callconv(.c) c_int {
    return strto(c_int, s, null, 10);
}

fn atol(s: [*:0]const u8) callconv(.c) c_long {
    return strto(c_long, s, null, 10);
}

fn atoll(s: [*:0]const u8) callconv(.c) c_longlong {
    return strto(c_longlong, s, null, 10);
}

fn abs(n: c_int) callconv(.c) c_int {
    return if (n < 0) -%n else n;
}

fn labs(n: c_long) callconv(.c) c_long {
    return if (n < 0) -%n else n;
}

fn llabs(n: c_longlong) callconv(.c) c_longlong {
    return if (n < 0) -%n else n;
}

fn Div(comptime T: type) type {
    return extern struct { quot: T, rem: T };
}

fn div(num: c_int, den: c_int) callconv(.c) Div(c_int) {
    return .{ .quot = @divTrunc(num, den), .rem = @rem(num, den) };
}

fn ldiv(num: c_long, den: c_long) callconv(.c) Div(c_long) {
    return .{ .quot = @divTrunc(num, den), .rem = @rem(num, den) };
}

fn lldiv(num: c_longlong, den: c_longlong) callconv(.c) Div(c_longlong) {
    return .{ .quot = @divTrunc(num, den), .rem = @rem(num, den) };
}

const Comparator = *const fn (?*const anyopaque, ?*const anyopaque) callconv(.c) c_int;

const SortContext = struct {
    base: [*]u8,
    size: usize,
    cmp: Comparator,

    fn at(ctx: SortContext, i: usize) [*]u8 {
        return ctx.base + i * ctx.size;
    }

    pub fn lessThan(ctx: SortContext, a: usize, b: usize) bool {
        return ctx.cmp(ctx.at(a), ctx.at(b)) < 0;
    }

    pub fn swap(ctx: SortContext, a: usize, b: usize) void {
        const x = ctx.at(a);
        const y = ctx.at(b);
        for (0..ctx.size) |i| std.mem.swap(u8, &x[i], &y[i]);
    }
};

fn qsort(base: ?*anyopaque, n: usize, size: usize, cmp: Comparator) callconv(.c) void {
    if (n < 2 or size == 0) return;
    std.sort.pdqContext(0, n, SortContext{ .base = @ptrCast(base), .size = size, .cmp = cmp });
}

fn bsearch(key: ?*const anyopaque, base: ?*const anyopaque, n: usize, size: usize, cmp: Comparator) callconv(.c) ?*anyopaque {
    const items: [*]const u8 = @ptrCast(base orelse return null);
    var lo: usize = 0;
    var hi: usize = n;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const item = items + mid * size;
        const order = cmp(key, item);
        if (order == 0) return @constCast(item);
        if (order < 0) hi = mid else lo = mid + 1;
    }
    return null;
}

/// There is no environment in a freestanding module.
fn getenv(name: [*:0]const u8) callconv(.c) ?[*:0]u8 {
    _ = name;
    return null;
}
