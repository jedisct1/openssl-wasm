//! string.h and strings.h.
//!
//! memcpy, memmove, memset, memcmp and strlen come from compiler_rt.

const std = @import("std");
const mem = std.mem;
const libc = @import("libc.zig");
const symbol = libc.symbol;
const malloc = @import("malloc.zig").malloc;
const E = libc.E;

comptime {
    symbol(&memchr, "memchr");
    symbol(&memrchr, "memrchr");
    symbol(&memmem, "memmem");
    symbol(&strnlen, "strnlen");
    symbol(&strcpy, "strcpy");
    symbol(&strncpy, "strncpy");
    symbol(&strcat, "strcat");
    symbol(&strncat, "strncat");
    symbol(&strcmp, "strcmp");
    symbol(&strncmp, "strncmp");
    symbol(&strcmp, "strcoll");
    symbol(&strchr, "strchr");
    symbol(&strrchr, "strrchr");
    symbol(&strstr, "strstr");
    symbol(&strspn, "strspn");
    symbol(&strcspn, "strcspn");
    symbol(&strpbrk, "strpbrk");
    symbol(&strtok, "strtok");
    symbol(&strtok_r, "strtok_r");
    symbol(&strdup, "strdup");
    symbol(&strndup, "strndup");
    symbol(&strerror, "strerror");
    symbol(&strerror_r, "strerror_r");
    symbol(&strcasecmp, "strcasecmp");
    symbol(&strncasecmp, "strncasecmp");
}

fn memchr(s: [*]const u8, c: c_int, n: usize) callconv(.c) ?[*]u8 {
    const i = mem.indexOfScalar(u8, s[0..n], @truncate(@as(c_uint, @bitCast(c)))) orelse return null;
    return @constCast(s + i);
}

fn memrchr(s: [*]const u8, c: c_int, n: usize) callconv(.c) ?[*]u8 {
    const i = mem.lastIndexOfScalar(u8, s[0..n], @truncate(@as(c_uint, @bitCast(c)))) orelse return null;
    return @constCast(s + i);
}

fn memmem(haystack: [*]const u8, haystack_len: usize, needle: [*]const u8, needle_len: usize) callconv(.c) ?[*]u8 {
    const i = mem.indexOf(u8, haystack[0..haystack_len], needle[0..needle_len]) orelse return null;
    return @constCast(haystack + i);
}

/// Only reads up to the terminator, which may come well before `max`.
fn strnlen(s: [*]const u8, max: usize) callconv(.c) usize {
    var i: usize = 0;
    while (i < max and s[i] != 0) i += 1;
    return i;
}

fn strcpy(dst: [*]u8, src: [*:0]const u8) callconv(.c) [*]u8 {
    const len = mem.len(src);
    @memcpy(dst[0 .. len + 1], src[0 .. len + 1]);
    return dst;
}

/// Copies at most n bytes and pads with zeros, without guaranteeing a terminator.
fn strncpy(dst: [*]u8, src: [*]const u8, n: usize) callconv(.c) [*]u8 {
    const len = strnlen(src, n);
    @memcpy(dst[0..len], src[0..len]);
    @memset(dst[len..n], 0);
    return dst;
}

fn strcat(dst: [*:0]u8, src: [*:0]const u8) callconv(.c) [*:0]u8 {
    _ = strcpy(dst + mem.len(dst), src);
    return dst;
}

fn strncat(dst: [*:0]u8, src: [*]const u8, n: usize) callconv(.c) [*:0]u8 {
    const end = dst + mem.len(dst);
    const len = strnlen(src, n);
    @memcpy(end[0..len], src[0..len]);
    end[len] = 0;
    return dst;
}

fn strcmp(a: [*:0]const u8, b: [*:0]const u8) callconv(.c) c_int {
    var i: usize = 0;
    while (a[i] == b[i] and a[i] != 0) i += 1;
    return @as(c_int, a[i]) - @as(c_int, b[i]);
}

fn strncmp(a: [*]const u8, b: [*]const u8, n: usize) callconv(.c) c_int {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (a[i] != b[i] or a[i] == 0) return @as(c_int, a[i]) - @as(c_int, b[i]);
    }
    return 0;
}

fn strcasecmp(a: [*:0]const u8, b: [*:0]const u8) callconv(.c) c_int {
    return strncasecmp(a, b, std.math.maxInt(usize));
}

fn strncasecmp(a: [*]const u8, b: [*]const u8, n: usize) callconv(.c) c_int {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const x = std.ascii.toLower(a[i]);
        const y = std.ascii.toLower(b[i]);
        if (x != y or x == 0) return @as(c_int, x) - @as(c_int, y);
    }
    return 0;
}

/// The terminator is part of the string here, so strchr(s, 0) finds it.
pub fn strchr(s: [*:0]const u8, c: c_int) callconv(.c) ?[*:0]u8 {
    const needle: u8 = @truncate(@as(c_uint, @bitCast(c)));
    var p = s;
    while (true) : (p += 1) {
        if (p[0] == needle) return @constCast(p);
        if (p[0] == 0) return null;
    }
}

fn strrchr(s: [*:0]const u8, c: c_int) callconv(.c) ?[*:0]u8 {
    const needle: u8 = @truncate(@as(c_uint, @bitCast(c)));
    const len = mem.len(s);
    const i = mem.lastIndexOfScalar(u8, s[0 .. len + 1], needle) orelse return null;
    return @constCast(s + i);
}

fn strstr(haystack: [*:0]const u8, needle: [*:0]const u8) callconv(.c) ?[*:0]u8 {
    const i = mem.indexOf(u8, mem.span(haystack), mem.span(needle)) orelse return null;
    return @constCast(haystack + i);
}

const ByteSet = std.StaticBitSet(256);

fn byteSet(chars: [*:0]const u8) ByteSet {
    var set: ByteSet = .empty;
    for (mem.span(chars)) |ch| set.set(ch);
    return set;
}

fn strspn(s: [*:0]const u8, accept: [*:0]const u8) callconv(.c) usize {
    const set = byteSet(accept);
    var i: usize = 0;
    while (s[i] != 0 and set.isSet(s[i])) i += 1;
    return i;
}

fn strcspn(s: [*:0]const u8, reject: [*:0]const u8) callconv(.c) usize {
    const set = byteSet(reject);
    var i: usize = 0;
    while (s[i] != 0 and !set.isSet(s[i])) i += 1;
    return i;
}

fn strpbrk(s: [*:0]const u8, accept: [*:0]const u8) callconv(.c) ?[*:0]u8 {
    const p = s + strcspn(s, accept);
    return if (p[0] != 0) @constCast(p) else null;
}

fn strtok_r(opt_s: ?[*:0]u8, sep: [*:0]const u8, state: *?[*:0]u8) callconv(.c) ?[*:0]u8 {
    var s = opt_s orelse state.* orelse return null;
    s += strspn(s, sep);
    if (s[0] == 0) {
        state.* = null;
        return null;
    }
    const end = s + strcspn(s, sep);
    if (end[0] == 0) {
        state.* = null;
    } else {
        end[0] = 0;
        state.* = end + 1;
    }
    return s;
}

var strtok_state: ?[*:0]u8 = null;

fn strtok(s: ?[*:0]u8, sep: [*:0]const u8) callconv(.c) ?[*:0]u8 {
    return strtok_r(s, sep, &strtok_state);
}

pub fn strdup(s: [*:0]const u8) callconv(.c) ?[*:0]u8 {
    return strndup(s, mem.len(s));
}

fn strndup(s: [*]const u8, n: usize) callconv(.c) ?[*:0]u8 {
    const len = strnlen(s, n);
    const copy: [*]u8 = @ptrCast(malloc(len + 1) orelse return null);
    @memcpy(copy[0..len], s[0..len]);
    copy[len] = 0;
    return copy[0..len :0].ptr;
}

fn strerror(err: c_int) callconv(.c) [*:0]u8 {
    return @constCast(message(err).ptr);
}

/// XSI variant, which returns an error code instead of a pointer.
fn strerror_r(err: c_int, buf: [*]u8, len: usize) callconv(.c) c_int {
    const msg = message(err);
    if (len == 0) return @intFromEnum(E.RANGE);
    const n = @min(msg.len, len - 1);
    @memcpy(buf[0..n], msg[0..n]);
    buf[n] = 0;
    return if (n < msg.len) @intFromEnum(E.RANGE) else 0;
}

fn message(err: c_int) [:0]const u8 {
    const code = std.math.cast(u16, err) orelse return "Unknown error";
    return switch (@as(E, @enumFromInt(code))) {
        .SUCCESS => "No error information",
        .@"2BIG" => "Argument list too long",
        .ACCES => "Permission denied",
        .ADDRINUSE => "Address in use",
        .ADDRNOTAVAIL => "Address not available",
        .AFNOSUPPORT => "Address family not supported by protocol",
        .AGAIN => "Resource temporarily unavailable",
        .ALREADY => "Operation already in progress",
        .BADF => "Bad file descriptor",
        .BADMSG => "Bad message",
        .BUSY => "Resource busy",
        .CANCELED => "Operation canceled",
        .CHILD => "No child process",
        .CONNABORTED => "Connection aborted",
        .CONNREFUSED => "Connection refused",
        .CONNRESET => "Connection reset by peer",
        .DEADLK => "Resource deadlock would occur",
        .DESTADDRREQ => "Destination address required",
        .DOM => "Domain error",
        .DQUOT => "Quota exceeded",
        .EXIST => "File exists",
        .FAULT => "Bad address",
        .FBIG => "File too large",
        .HOSTUNREACH => "Host is unreachable",
        .IDRM => "Identifier removed",
        .ILSEQ => "Illegal byte sequence",
        .INPROGRESS => "Operation in progress",
        .INTR => "Interrupted system call",
        .INVAL => "Invalid argument",
        .IO => "I/O error",
        .ISCONN => "Socket is connected",
        .ISDIR => "Is a directory",
        .LOOP => "Symbolic link loop",
        .MFILE => "No file descriptors available",
        .MLINK => "Too many links",
        .MSGSIZE => "Message too large",
        .MULTIHOP => "Multihop attempted",
        .NAMETOOLONG => "Filename too long",
        .NETDOWN => "Network is down",
        .NETRESET => "Connection reset by network",
        .NETUNREACH => "Network unreachable",
        .NFILE => "Too many open files in system",
        .NOBUFS => "No buffer space available",
        .NODEV => "No such device",
        .NOENT => "No such file or directory",
        .NOEXEC => "Exec format error",
        .NOLCK => "No locks available",
        .NOLINK => "Link has been severed",
        .NOMEM => "Out of memory",
        .NOMSG => "No message of desired type",
        .NOPROTOOPT => "Protocol not available",
        .NOSPC => "No space left on device",
        .NOSYS => "Function not implemented",
        .NOTCONN => "Socket not connected",
        .NOTDIR => "Not a directory",
        .NOTEMPTY => "Directory not empty",
        .NOTRECOVERABLE => "State not recoverable",
        .NOTSOCK => "Not a socket",
        .OPNOTSUPP => "Not supported",
        .NOTTY => "Not a tty",
        .NXIO => "No such device or address",
        .OVERFLOW => "Value too large for data type",
        .OWNERDEAD => "Previous owner died",
        .PERM => "Operation not permitted",
        .PIPE => "Broken pipe",
        .PROTO => "Protocol error",
        .PROTONOSUPPORT => "Protocol not supported",
        .PROTOTYPE => "Protocol wrong type for socket",
        .RANGE => "Result not representable",
        .ROFS => "Read-only file system",
        .SPIPE => "Invalid seek",
        .SRCH => "No such process",
        .STALE => "Stale file handle",
        .TIMEDOUT => "Operation timed out",
        .TXTBSY => "Text file busy",
        .XDEV => "Cross-device link",
        .NOTCAPABLE => "Capabilities insufficient",
        _ => "Unknown error",
    };
}
