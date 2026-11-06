//! A small C library for wasm32-freestanding.
//!
//! It implements what OpenSSL needs, plus the obvious neighbors of those functions.
//! Randomness and clocks come from the host through two WASI preview1 imports,
//! `random_get` and `clock_time_get`, so any WASI runtime can run the result as is.
//! Everything else is self-contained.

const std = @import("std");

pub const panic = std.debug.no_panic;

pub const E = std.os.wasi.errno_t;

/// Symbols are weak so that an application can replace any of them,
/// and hidden so that they don't end up in the module's exports.
pub inline fn symbol(comptime ptr: anytype, comptime name: []const u8) void {
    @export(ptr, .{ .name = name, .linkage = .weak, .visibility = .hidden });
}

/// errno.h uses the WASI numbering, so WASI error codes can be stored as is.
pub var errno: c_int = 0;

pub fn setErrno(e: E) void {
    errno = @intFromEnum(e);
}

fn abort() callconv(.c) noreturn {
    @trap();
}

fn __assert_fail(expr: [*:0]const u8, file: [*:0]const u8, line: c_int, func: [*:0]const u8) callconv(.c) noreturn {
    _ = expr;
    _ = file;
    _ = line;
    _ = func;
    @trap();
}

comptime {
    symbol(&errno, "errno");
    symbol(&abort, "abort");
    symbol(&__assert_fail, "__assert_fail");

    _ = @import("ctype.zig");
    _ = @import("malloc.zig");
    _ = @import("printf.zig");
    _ = @import("stdio.zig");
    _ = @import("stdlib.zig");
    _ = @import("string.zig");
    _ = @import("time.zig");
    _ = @import("unistd.zig");
}
