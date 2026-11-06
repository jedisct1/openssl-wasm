//! sscanf() without floating point, scansets or wide characters.
//! Unsupported conversions stop the scan as a matching failure.

const std = @import("std");
const libc = @import("libc.zig");
const symbol = libc.symbol;
const isspace = @import("ctype.zig").isspace;
const parseInt = @import("stdlib.zig").parseInt;

comptime {
    symbol(&sscanf, "sscanf");
    symbol(&vsscanf, "vsscanf");
}

const EOF: c_int = -1;

const Size = enum { char, short, int, long, long_long, size };

fn sscanf(s: [*:0]const u8, fmt: [*:0]const u8, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);
    return scan(s, fmt, &ap);
}

fn vsscanf(s: [*:0]const u8, fmt: [*:0]const u8, ap: std.builtin.VaList) callconv(.c) c_int {
    var copy = ap;
    return scan(s, fmt, &copy);
}

fn skipSpaces(p: [*:0]const u8) [*:0]const u8 {
    var q = p;
    while (isspace(q[0]) != 0) q += 1;
    return q;
}

fn store(ap: *std.builtin.VaList, size: Size, value: u64) void {
    switch (size) {
        .char => @cVaArg(ap, *u8).* = @truncate(value),
        .short => @cVaArg(ap, *c_ushort).* = @truncate(value),
        .int => @cVaArg(ap, *c_uint).* = @truncate(value),
        .long => @cVaArg(ap, *c_ulong).* = @truncate(value),
        .long_long => @cVaArg(ap, *c_ulonglong).* = @truncate(value),
        .size => @cVaArg(ap, *usize).* = @truncate(value),
    }
}

fn scan(s: [*:0]const u8, fmt: [*:0]const u8, ap: *std.builtin.VaList) c_int {
    var in = s;
    var f = fmt;
    var assigned: c_int = 0;
    var converted = false;

    while (f[0] != 0) : (f += 1) {
        if (isspace(f[0]) != 0) {
            in = skipSpaces(in);
            continue;
        }
        if (f[0] != '%' or f[1] == '%') {
            // %% skips leading white space like other conversions, plain characters don't.
            if (f[0] == '%') {
                f += 1;
                in = skipSpaces(in);
            }
            if (in[0] == 0) return if (converted) assigned else EOF;
            if (in[0] != f[0]) break;
            in += 1;
            continue;
        }
        f += 1;

        const suppress = f[0] == '*';
        if (suppress) f += 1;

        var width: usize = 0;
        while (f[0] >= '0' and f[0] <= '9') : (f += 1) width = width *| 10 +| (f[0] - '0');

        var size: Size = .int;
        switch (f[0]) {
            'h' => {
                f += 1;
                size = .short;
                if (f[0] == 'h') {
                    f += 1;
                    size = .char;
                }
            },
            'l' => {
                f += 1;
                size = .long;
                if (f[0] == 'l') {
                    f += 1;
                    size = .long_long;
                }
            },
            'j' => {
                f += 1;
                size = .long_long;
            },
            'z', 't' => {
                f += 1;
                size = .size;
            },
            else => {},
        }

        const conv = f[0];
        if (conv == 'n') {
            if (!suppress) store(ap, size, @intFromPtr(in) - @intFromPtr(s));
            continue;
        }
        if (conv != 'c') in = skipSpaces(in);
        if (in[0] == 0) return if (converted) assigned else EOF;

        switch (conv) {
            'd', 'i', 'u', 'o', 'x', 'X' => {
                const base: c_int = switch (conv) {
                    'd', 'u' => 10,
                    'i' => 0,
                    'o' => 8,
                    else => 16,
                };
                const max = if (width == 0) std.math.maxInt(usize) else width;
                const value: u64, const len = if (conv == 'd' or conv == 'i') blk: {
                    const v, const l = parseInt(i64, in, max, base);
                    break :blk .{ @bitCast(v), l };
                } else parseInt(u64, in, max, base);
                if (len == 0) break;
                in += len;
                if (!suppress) store(ap, size, value);
            },
            'c' => {
                if (size == .long) break;
                const n = if (width == 0) 1 else width;
                // %c needs exactly n characters, running out of input first is an input failure.
                if (std.mem.len(in) < n) return if (converted) assigned else EOF;
                if (!suppress) @memcpy(@cVaArg(ap, [*]u8)[0..n], in[0..n]);
                in += n;
            },
            's' => {
                if (size == .long) break;
                var n: usize = 0;
                while (in[n] != 0 and isspace(in[n]) == 0 and (width == 0 or n < width)) n += 1;
                if (!suppress) {
                    const dst = @cVaArg(ap, [*]u8);
                    @memcpy(dst[0..n], in[0..n]);
                    dst[n] = 0;
                }
                in += n;
            },
            else => break,
        }
        converted = true;
        if (!suppress) assigned += 1;
    }
    return assigned;
}
