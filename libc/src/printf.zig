//! snprintf() and friends.
//!
//! Every C99 conversion is supported, except positional arguments (%1$d) and
//! wide characters (%lc, %ls).
//! Floating point conversions are exact: digits come from the full decimal
//! expansion of the value and rounding is to nearest, ties to even, as in glibc.
//! long double arguments are converted to double.

const std = @import("std");
const libc = @import("libc.zig");
const symbol = libc.symbol;
const VaList = std.builtin.VaList;

comptime {
    symbol(&snprintf, "snprintf");
    symbol(&vsnprintf, "vsnprintf");
    symbol(&sprintf, "sprintf");
    symbol(&vsprintf, "vsprintf");
}

fn snprintf(buf: ?[*]u8, n: usize, fmt: [*:0]const u8, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);
    return format(buf, n, fmt, &ap);
}

fn vsnprintf(buf: ?[*]u8, n: usize, fmt: [*:0]const u8, ap: VaList) callconv(.c) c_int {
    var copy = ap;
    return format(buf, n, fmt, &copy);
}

/// Bounded by the end of the address space rather than SIZE_MAX, so that
/// buf + n never wraps around.
fn unbounded(buf: [*]u8) usize {
    return std.math.maxInt(usize) - @intFromPtr(buf);
}

fn sprintf(buf: [*]u8, fmt: [*:0]const u8, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);
    return format(buf, unbounded(buf), fmt, &ap);
}

fn vsprintf(buf: [*]u8, fmt: [*:0]const u8, ap: VaList) callconv(.c) c_int {
    var copy = ap;
    return format(buf, unbounded(buf), fmt, &copy);
}

/// Stores what fits, and counts everything that would have been written.
const Writer = struct {
    buf: ?[*]u8,
    capacity: usize,
    len: usize = 0,

    fn write(w: *Writer, bytes: []const u8) void {
        if (w.buf) |buf| {
            if (w.len < w.capacity) {
                const n = @min(bytes.len, w.capacity - w.len);
                @memcpy(buf[w.len..][0..n], bytes[0..n]);
            }
        }
        w.len +|= bytes.len;
    }

    fn pad(w: *Writer, c: u8, count: usize) void {
        const chunk: [32]u8 = @splat(c);
        var left = count;
        while (left > 0) {
            const n = @min(left, chunk.len);
            w.write(chunk[0..n]);
            left -= n;
        }
    }
};

const Spec = struct {
    left: bool = false,
    plus: bool = false,
    space: bool = false,
    alt: bool = false,
    zero: bool = false,
    width: usize = 0,
    precision: ?usize = null,
};

const Length = enum { none, hh, h, l, ll, j, z, t, L };

fn format(buf: ?[*]u8, n: usize, fmt: [*:0]const u8, ap: *VaList) c_int {
    // One byte is kept for the terminator.
    var w: Writer = .{ .buf = buf, .capacity = n -| 1 };
    const ok = formatTo(&w, fmt, ap);
    if (buf) |b| {
        if (n > 0) b[@min(w.len, n - 1)] = 0;
    }
    if (!ok) {
        libc.setErrno(.INVAL);
        return -1;
    }
    return std.math.cast(c_int, w.len) orelse {
        libc.setErrno(.OVERFLOW);
        return -1;
    };
}

fn formatTo(w: *Writer, fmt: [*:0]const u8, ap: *VaList) bool {
    var f = fmt;
    while (f[0] != 0) {
        if (f[0] != '%') {
            const start = f;
            while (f[0] != 0 and f[0] != '%') f += 1;
            w.write(start[0 .. @intFromPtr(f) - @intFromPtr(start)]);
            continue;
        }
        f += 1;

        var spec: Spec = .{};
        while (true) : (f += 1) {
            switch (f[0]) {
                '-' => spec.left = true,
                '+' => spec.plus = true,
                ' ' => spec.space = true,
                '#' => spec.alt = true,
                '0' => spec.zero = true,
                else => break,
            }
        }

        if (f[0] == '*') {
            f += 1;
            const width = @cVaArg(ap, c_int);
            if (width < 0) spec.left = true;
            spec.width = @abs(width);
        } else {
            while (f[0] >= '0' and f[0] <= '9') : (f += 1) spec.width = spec.width *| 10 +| (f[0] - '0');
        }
        if (f[0] == '$') return false;

        if (f[0] == '.') {
            f += 1;
            if (f[0] == '*') {
                f += 1;
                const precision = @cVaArg(ap, c_int);
                spec.precision = if (precision < 0) null else @intCast(precision);
            } else {
                var precision: usize = 0;
                while (f[0] >= '0' and f[0] <= '9') : (f += 1) precision = precision *| 10 +| (f[0] - '0');
                spec.precision = precision;
            }
        }

        var length: Length = .none;
        switch (f[0]) {
            'h' => {
                f += 1;
                length = .h;
                if (f[0] == 'h') {
                    f += 1;
                    length = .hh;
                }
            },
            'l' => {
                f += 1;
                length = .l;
                if (f[0] == 'l') {
                    f += 1;
                    length = .ll;
                }
            },
            'j' => {
                f += 1;
                length = .j;
            },
            'z' => {
                f += 1;
                length = .z;
            },
            't' => {
                f += 1;
                length = .t;
            },
            'L' => {
                f += 1;
                length = .L;
            },
            else => {},
        }

        const conv = f[0];
        if (conv == 0) return false;
        f += 1;
        switch (conv) {
            '%' => w.write("%"),
            'd', 'i' => {
                const value = signedArg(ap, length);
                formatInt(w, spec, @abs(value), value < 0, true, 10, false);
            },
            'u' => formatInt(w, spec, unsignedArg(ap, length), false, false, 10, false),
            'o' => formatInt(w, spec, unsignedArg(ap, length), false, false, 8, false),
            'x' => formatInt(w, spec, unsignedArg(ap, length), false, false, 16, false),
            'X' => formatInt(w, spec, unsignedArg(ap, length), false, false, 16, true),
            'p' => {
                const ptr = @cVaArg(ap, usize);
                if (ptr == 0) {
                    formatString(w, spec, "(nil)");
                } else {
                    var p = spec;
                    p.alt = true;
                    formatInt(w, p, ptr, false, false, 16, false);
                }
            },
            'c' => {
                if (length == .l) return false;
                const c = [1]u8{@truncate(@as(c_uint, @bitCast(@cVaArg(ap, c_int))))};
                formatString(w, spec, &c);
            },
            's' => {
                if (length == .l) return false;
                const opt_s = @cVaArg(ap, ?[*:0]const u8);
                const s: []const u8 = if (opt_s) |p|
                    p[0..strnlen(p, spec.precision)]
                else
                    "(null)"[0..@min(6, spec.precision orelse 6)];
                formatString(w, spec, s);
            },
            'n' => storeCount(ap, length, w.len),
            'f', 'F', 'e', 'E', 'g', 'G', 'a', 'A' => {
                const value: f64 = if (length == .L) @floatCast(@cVaArg(ap, c_longdouble)) else @cVaArg(ap, f64);
                formatFloat(w, spec, value, conv);
            },
            else => return false,
        }
    }
    return true;
}

fn strnlen(s: [*:0]const u8, max: ?usize) usize {
    const limit = max orelse return std.mem.len(s);
    var i: usize = 0;
    while (i < limit and s[i] != 0) i += 1;
    return i;
}

fn signedArg(ap: *VaList, length: Length) i64 {
    return switch (length) {
        .hh => @as(i8, @truncate(@cVaArg(ap, c_int))),
        .h => @as(c_short, @truncate(@cVaArg(ap, c_int))),
        .none, .L => @cVaArg(ap, c_int),
        .l => @cVaArg(ap, c_long),
        .ll, .j => @cVaArg(ap, c_longlong),
        .z, .t => @cVaArg(ap, isize),
    };
}

fn unsignedArg(ap: *VaList, length: Length) u64 {
    return switch (length) {
        .hh => @as(u8, @truncate(@cVaArg(ap, c_uint))),
        .h => @as(c_ushort, @truncate(@cVaArg(ap, c_uint))),
        .none, .L => @cVaArg(ap, c_uint),
        .l => @cVaArg(ap, c_ulong),
        .ll, .j => @cVaArg(ap, c_ulonglong),
        .z, .t => @cVaArg(ap, usize),
    };
}

fn storeCount(ap: *VaList, length: Length, count: usize) void {
    const signed: isize = @bitCast(count);
    switch (length) {
        .hh => @cVaArg(ap, *i8).* = @truncate(signed),
        .h => @cVaArg(ap, *c_short).* = @truncate(signed),
        .none, .L => @cVaArg(ap, *c_int).* = @truncate(signed),
        .l => @cVaArg(ap, *c_long).* = @truncate(signed),
        .ll, .j => @cVaArg(ap, *c_longlong).* = @intCast(count),
        .z, .t => @cVaArg(ap, *usize).* = count,
    }
}

/// A piece of output: either literal bytes or a run of zeros.
const Segment = union(enum) {
    bytes: []const u8,
    zeros: usize,

    fn len(s: Segment) usize {
        return switch (s) {
            .bytes => |b| b.len,
            .zeros => |n| n,
        };
    }
};

/// Writes the prefix (sign, 0x), then the segments, padded to the field width.
/// With `zero_fill`, the padding is made of zeros placed after the prefix.
fn emit(w: *Writer, spec: Spec, prefix: []const u8, segments: []const Segment, zero_fill: bool) void {
    var content = prefix.len;
    for (segments) |s| content +|= s.len();
    const padding = spec.width -| content;
    if (!spec.left and !zero_fill) w.pad(' ', padding);
    w.write(prefix);
    if (!spec.left and zero_fill) w.pad('0', padding);
    for (segments) |s| switch (s) {
        .bytes => |b| w.write(b),
        .zeros => |n| w.pad('0', n),
    };
    if (spec.left) w.pad(' ', padding);
}

fn formatString(w: *Writer, spec: Spec, s: []const u8) void {
    emit(w, spec, "", &.{.{ .bytes = s }}, false);
}

fn signPrefix(spec: Spec, negative: bool) []const u8 {
    if (negative) return "-";
    if (spec.plus) return "+";
    if (spec.space) return " ";
    return "";
}

fn formatInt(w: *Writer, spec: Spec, magnitude: u64, negative: bool, signed: bool, base: u8, upper: bool) void {
    const digits_set: *const [16]u8 = if (upper) "0123456789ABCDEF" else "0123456789abcdef";
    var tmp: [64]u8 = undefined;
    var i: usize = tmp.len;
    var v = magnitude;
    while (v != 0) : (v /= base) {
        i -= 1;
        tmp[i] = digits_set[@intCast(v % base)];
    }
    const digits = tmp[i..];

    // With an explicit precision of zero, the value zero prints no digits at all.
    const precision = spec.precision orelse 1;
    var zeros = precision -| digits.len;
    if (base == 8 and spec.alt and zeros == 0 and (digits.len == 0 or digits[0] != '0')) zeros = 1;

    const prefix: []const u8 = if (signed)
        signPrefix(spec, negative)
    else if (base == 16 and spec.alt and magnitude != 0)
        (if (upper) "0X" else "0x")
    else
        "";
    emit(w, spec, prefix, &.{ .{ .zeros = zeros }, .{ .bytes = digits } }, spec.zero and spec.precision == null);
}

/// The exact decimal expansion of a finite double: value = 0.d0 d1 d2 ... * 10^point.
/// There are no leading or trailing zeros, and zero has no digits at all.
/// The longest expansion is the smallest subnormal, 2^-1074, with 1074 fractional digits.
const Decimal = struct {
    buf: [1500]u8 = undefined,
    len: usize = 0,
    point: i32 = 0,

    fn digits(d: *const Decimal) []const u8 {
        return d.buf[0..d.len];
    }

    fn init(value: f64) Decimal {
        var d: Decimal = .{};
        const bits: u64 = @bitCast(value);
        const biased: i32 = @intCast((bits >> 52) & 0x7ff);
        var mantissa = bits & ((1 << 52) - 1);
        var exponent: i32 = -1074;
        if (biased != 0) {
            mantissa |= 1 << 52;
            exponent = biased - 1075;
        }
        if (mantissa == 0) return d;
        const tz = @ctz(mantissa);
        mantissa >>= @intCast(tz);
        exponent += @intCast(tz);

        // value = mantissa * 2^exponent, with an odd mantissa.
        var limbs: [36]u32 = undefined;
        if (exponent >= 0) {
            const n = setShifted(&limbs, mantissa, @intCast(exponent));
            d.appendInteger(limbs[0..n]);
            d.point = @intCast(d.len);
        } else {
            const k: u32 = @intCast(-exponent);
            const int_part: u64 = if (k < 64) mantissa >> @intCast(k) else 0;
            const frac_part: u64 = if (k < 64) mantissa & ((@as(u64, 1) << @intCast(k)) - 1) else mantissa;
            if (int_part != 0) {
                const n = setShifted(&limbs, int_part, 0);
                d.appendInteger(limbs[0..n]);
            }
            d.point = @intCast(d.len);
            // Scale the fraction so that its binary point falls on a limb boundary.
            const frac_limbs = (k + 31) / 32;
            _ = setShifted(limbs[0..frac_limbs], frac_part, frac_limbs * 32 - k);
            d.appendFraction(limbs[0..frac_limbs]);
        }
        d.trim();
        return d;
    }

    /// Clears `limbs` and stores `value << shift` in it, returning the number of limbs in use.
    fn setShifted(limbs: []u32, value: u64, shift: usize) usize {
        @memset(limbs, 0);
        const wide = @as(u128, value) << @intCast(shift % 32);
        var i = shift / 32;
        var rest = wide;
        while (rest != 0 and i < limbs.len) : (i += 1) {
            limbs[i] = @truncate(rest);
            rest >>= 32;
        }
        return i;
    }

    fn appendChunk(d: *Decimal, chunk: u32, pad: bool) void {
        var tmp: [9]u8 = undefined;
        var v = chunk;
        var i: usize = tmp.len;
        while (i > 0) {
            i -= 1;
            tmp[i] = '0' + @as(u8, @intCast(v % 10));
            v /= 10;
            if (!pad and v == 0) break;
        }
        @memcpy(d.buf[d.len..][0 .. tmp.len - i], tmp[i..]);
        d.len += tmp.len - i;
    }

    /// Integer digits, by repeated division by 10^9.
    fn appendInteger(d: *Decimal, limbs: []u32) void {
        var chunks: [40]u32 = undefined;
        var count: usize = 0;
        var n = limbs.len;
        while (n > 0 and limbs[n - 1] == 0) n -= 1;
        while (n > 0) {
            var rem: u64 = 0;
            var i = n;
            while (i > 0) {
                i -= 1;
                const cur = (rem << 32) | limbs[i];
                limbs[i] = @intCast(cur / 1_000_000_000);
                rem = cur % 1_000_000_000;
            }
            chunks[count] = @intCast(rem);
            count += 1;
            while (n > 0 and limbs[n - 1] == 0) n -= 1;
        }
        var i = count;
        while (i > 0) {
            i -= 1;
            d.appendChunk(chunks[i], i != count - 1);
        }
    }

    /// Fractional digits of limbs / 2^(32 * limbs.len), by repeated multiplication by 10^9.
    /// The expansion terminates, so this stops on its own.
    fn appendFraction(d: *Decimal, limbs: []u32) void {
        var lo: usize = 0;
        while (true) {
            while (lo < limbs.len and limbs[lo] == 0) lo += 1;
            if (lo == limbs.len) break;
            var carry: u64 = 0;
            for (limbs[lo..]) |*limb| {
                const t = @as(u64, limb.*) * 1_000_000_000 + carry;
                limb.* = @truncate(t);
                carry = t >> 32;
            }
            d.appendChunk(@intCast(carry), true);
        }
    }

    /// Drops leading zeros (adjusting the decimal point) and trailing zeros.
    fn trim(d: *Decimal) void {
        var lead: usize = 0;
        while (lead < d.len and d.buf[lead] == '0') lead += 1;
        if (lead > 0) {
            std.mem.copyForwards(u8, d.buf[0 .. d.len - lead], d.buf[lead..d.len]);
            d.len -= lead;
            d.point -= @intCast(lead);
        }
        while (d.len > 0 and d.buf[d.len - 1] == '0') d.len -= 1;
        if (d.len == 0) d.point = 0;
    }

    /// Keeps the first `keep` digits, rounding to nearest with ties to even.
    fn round(d: *Decimal, keep: i64) void {
        if (keep >= d.len) return;
        if (keep < 0) {
            d.len = 0;
            d.point = 0;
            return;
        }
        const k: usize = @intCast(keep);
        const next = d.buf[k];
        // Without trailing zeros, any digit after the rounding one makes the rest nonzero.
        const up = next > '5' or (next == '5' and (k + 1 < d.len or (k > 0 and (d.buf[k - 1] - '0') % 2 == 1)));
        d.len = k;
        if (up) {
            var i = k;
            const carried = while (i > 0) {
                i -= 1;
                if (d.buf[i] != '9') {
                    d.buf[i] += 1;
                    break false;
                }
                d.buf[i] = '0';
            } else true;
            if (carried) {
                d.buf[0] = '1';
                d.len = 1;
                d.point += 1;
            }
        }
        while (d.len > 0 and d.buf[d.len - 1] == '0') d.len -= 1;
        if (d.len == 0) d.point = 0;
    }
};

fn formatFloat(w: *Writer, spec: Spec, value: f64, conv: u8) void {
    const upper = std.ascii.isUpper(conv);
    const prefix = signPrefix(spec, std.math.signbit(value));
    const abs = @abs(value);

    if (std.math.isNan(abs) or std.math.isInf(abs)) {
        const body: []const u8 = if (std.math.isNan(abs))
            (if (upper) "NAN" else "nan")
        else
            (if (upper) "INF" else "inf");
        emit(w, spec, prefix, &.{.{ .bytes = body }}, false);
        return;
    }
    if (std.ascii.toLower(conv) == 'a') {
        hexFloat(w, spec, prefix, abs, upper);
        return;
    }

    var d: Decimal = .init(abs);
    switch (std.ascii.toLower(conv)) {
        'f' => fixed(w, spec, prefix, &d, spec.precision orelse 6, false),
        'e' => exponential(w, spec, prefix, &d, spec.precision orelse 6, upper, false),
        'g' => {
            // %g picks a style from the exponent the value has once rounded,
            // then drops trailing zeros unless # is given.
            const p = @max(spec.precision orelse 6, 1);
            var rounded = d;
            rounded.round(@intCast(p));
            const exponent: i64 = if (rounded.len == 0) 0 else rounded.point - 1;
            if (exponent >= -4 and exponent < p) {
                fixed(w, spec, prefix, &d, @intCast(@as(i64, @intCast(p)) - 1 - exponent), !spec.alt);
            } else {
                exponential(w, spec, prefix, &d, p - 1, upper, !spec.alt);
            }
        },
        else => unreachable,
    }
}

fn fixed(w: *Writer, spec: Spec, prefix: []const u8, d: *Decimal, precision: usize, strip: bool) void {
    d.round(d.point + @as(i64, @intCast(@min(precision, std.math.maxInt(i32)))));
    const digits = d.digits();
    const point: i64 = d.point;

    var segments: [6]Segment = undefined;
    var n: usize = 0;
    if (point <= 0) {
        segments[n] = .{ .bytes = "0" };
        n += 1;
    } else {
        const int_len: usize = @intCast(point);
        segments[n] = .{ .bytes = digits[0..@min(digits.len, int_len)] };
        segments[n + 1] = .{ .zeros = int_len -| digits.len };
        n += 2;
    }

    const frac_start: usize = @intCast(@max(point, 0));
    var lead_zeros: usize = if (point < 0) @min(@as(usize, @intCast(-point)), precision) else 0;
    const frac_digits = if (frac_start < digits.len) digits[frac_start..] else digits[0..0];
    var trailing = precision - lead_zeros - frac_digits.len;
    if (strip) {
        trailing = 0;
        if (frac_digits.len == 0) lead_zeros = 0;
    }
    if (lead_zeros + frac_digits.len + trailing > 0 or spec.alt) {
        segments[n] = .{ .bytes = "." };
        n += 1;
    }
    segments[n] = .{ .zeros = lead_zeros };
    segments[n + 1] = .{ .bytes = frac_digits };
    segments[n + 2] = .{ .zeros = trailing };
    n += 3;
    emit(w, spec, prefix, segments[0..n], spec.zero);
}

fn exponential(w: *Writer, spec: Spec, prefix: []const u8, d: *Decimal, precision: usize, upper: bool, strip: bool) void {
    d.round(@as(i64, @intCast(@min(precision, std.math.maxInt(i32)))) + 1);
    const digits = d.digits();
    const exponent: i64 = if (digits.len == 0) 0 else d.point - 1;
    const first: []const u8 = if (digits.len == 0) "0" else digits[0..1];
    const rest = if (digits.len > 1) digits[1..] else digits[0..0];
    const trailing = if (strip) 0 else precision - rest.len;

    var exp_buf: [8]u8 = undefined;
    const exp = std.fmt.bufPrint(&exp_buf, "{c}{c}{d:0>2}", .{
        if (upper) @as(u8, 'E') else 'e',
        if (exponent < 0) @as(u8, '-') else '+',
        @abs(exponent),
    }) catch unreachable;
    const dot: []const u8 = if (rest.len + trailing > 0 or spec.alt) "." else "";
    emit(w, spec, prefix, &.{
        .{ .bytes = first },
        .{ .bytes = dot },
        .{ .bytes = rest },
        .{ .zeros = trailing },
        .{ .bytes = exp },
    }, spec.zero);
}

/// %a: hexadecimal mantissa and binary exponent, as in 0x1.8p+1.
/// Subnormals are written as 0x0.xxxp-1022, like glibc does.
/// With a precision, the mantissa is rounded to nearest, ties to even.
fn hexFloat(w: *Writer, spec: Spec, sign: []const u8, abs: f64, upper: bool) void {
    const bits: u64 = @bitCast(abs);
    const biased: i32 = @intCast(bits >> 52);
    var mantissa: u64 = bits & ((1 << 52) - 1);
    var exponent: i32 = 0;
    var lead: u64 = 0;
    if (biased != 0) {
        lead = 1;
        exponent = biased - 1023;
    } else if (mantissa != 0) {
        exponent = -1022;
    }

    var frac_digits: usize = 13;
    if (spec.precision) |p| {
        if (p < 13) {
            const shift: u6 = @intCast((13 - p) * 4);
            const full = (lead << 52) | mantissa;
            const rem = full & ((@as(u64, 1) << shift) - 1);
            const half = @as(u64, 1) << (shift - 1);
            var rounded = full >> shift;
            if (rem > half or (rem == half and rounded & 1 == 1)) rounded += 1;
            const frac_bits: u6 = @intCast(p * 4);
            lead = rounded >> frac_bits;
            mantissa = rounded & ((@as(u64, 1) << frac_bits) - 1);
            frac_digits = p;
        }
    } else {
        while (frac_digits > 0 and mantissa & 0xf == 0) {
            mantissa >>= 4;
            frac_digits -= 1;
        }
    }

    const digits_set: *const [16]u8 = if (upper) "0123456789ABCDEF" else "0123456789abcdef";
    var frac: [13]u8 = undefined;
    for (0..frac_digits) |i| {
        const nibble = (mantissa >> @intCast((frac_digits - 1 - i) * 4)) & 0xf;
        frac[i] = digits_set[@intCast(nibble)];
    }
    const extra_zeros = (spec.precision orelse frac_digits) -| frac_digits;

    var exp_buf: [8]u8 = undefined;
    const exp = std.fmt.bufPrint(&exp_buf, "{c}{c}{d}", .{
        if (upper) @as(u8, 'P') else 'p',
        if (exponent < 0) @as(u8, '-') else '+',
        @abs(exponent),
    }) catch unreachable;

    var prefix_buf: [3]u8 = undefined;
    @memcpy(prefix_buf[0..sign.len], sign);
    @memcpy(prefix_buf[sign.len..][0..2], if (upper) "0X" else "0x");
    const dot: []const u8 = if (frac_digits + extra_zeros > 0 or spec.alt) "." else "";
    const lead_digit = [1]u8{digits_set[@intCast(lead)]};
    emit(w, spec, prefix_buf[0 .. sign.len + 2], &.{
        .{ .bytes = &lead_digit },
        .{ .bytes = dot },
        .{ .bytes = frac[0..frac_digits] },
        .{ .zeros = extra_zeros },
        .{ .bytes = exp },
    }, spec.zero);
}
