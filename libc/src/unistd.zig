//! Process, entropy and filesystem entry points.
//! There is no filesystem, so every path lookup fails.

const std = @import("std");
const wasi = std.os.wasi;
const libc = @import("libc.zig");
const symbol = libc.symbol;

comptime {
    symbol(&getentropy, "getentropy");
    symbol(&getpid, "getpid");
    symbol(&getuid, "getuid");
    symbol(&getuid, "geteuid");
    symbol(&getuid, "getgid");
    symbol(&getuid, "getegid");
    symbol(&getpagesize, "getpagesize");
    symbol(&stat, "stat");
    symbol(&fstat, "fstat");
    symbol(&open, "open");
}

/// Same contract as OpenBSD, glibc and wasi-libc: at most 256 bytes per call,
/// EIO beyond that. POSIX.1-2024 specifies EINVAL instead.
fn getentropy(buf: [*]u8, len: usize) callconv(.c) c_int {
    if (len > 256) {
        libc.setErrno(.IO);
        return -1;
    }
    const err = wasi.random_get(buf, len);
    if (err != .SUCCESS) {
        libc.setErrno(err);
        return -1;
    }
    return 0;
}

/// There is a single process, and it never forks.
fn getpid() callconv(.c) c_int {
    return 1;
}

fn getuid() callconv(.c) c_uint {
    return 0;
}

fn getpagesize() callconv(.c) c_int {
    return std.wasm.page_size;
}

fn stat(path: [*:0]const u8, st: *anyopaque) callconv(.c) c_int {
    _ = path;
    _ = st;
    libc.setErrno(.NOENT);
    return -1;
}

fn fstat(fd: c_int, st: *anyopaque) callconv(.c) c_int {
    _ = fd;
    _ = st;
    libc.setErrno(.BADF);
    return -1;
}

fn open(path: [*:0]const u8, flags: c_int, ...) callconv(.c) c_int {
    _ = path;
    _ = flags;
    libc.setErrno(.NOENT);
    return -1;
}
