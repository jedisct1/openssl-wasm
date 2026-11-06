//! Clocks come from the host through WASI's clock_time_get().
//! There are no time zones, local time is UTC.

const std = @import("std");
const wasi = std.os.wasi;
const libc = @import("libc.zig");
const symbol = libc.symbol;

comptime {
    symbol(&time, "time");
    symbol(&gettimeofday, "gettimeofday");
    symbol(&clock_gettime, "clock_gettime");
    symbol(&gmtime_r, "gmtime_r");
    symbol(&gmtime_r, "localtime_r");
    symbol(&gmtime, "gmtime");
    symbol(&gmtime, "localtime");
    symbol(&timegm, "timegm");
    symbol(&timegm, "mktime");
    symbol(&difftime, "difftime");
    symbol(&nanosleep, "nanosleep");
    symbol(&sleep, "sleep");
    symbol(&usleep, "usleep");
}

const time_t = i64;
const ns_per_s = std.time.ns_per_s;
const s_per_day = std.time.s_per_day;

const Timespec = extern struct {
    tv_sec: time_t,
    tv_nsec: c_long,
};

const Timeval = extern struct {
    tv_sec: time_t,
    tv_usec: i64,
};

const Tm = extern struct {
    tm_sec: c_int,
    tm_min: c_int,
    tm_hour: c_int,
    tm_mday: c_int,
    tm_mon: c_int,
    tm_year: c_int,
    tm_wday: c_int,
    tm_yday: c_int,
    tm_isdst: c_int,
    tm_gmtoff: c_int,
    tm_zone: ?[*:0]const u8,
    __tm_nsec: c_int,
};

/// Nanoseconds since the epoch for the realtime clock, or since an arbitrary point for the monotonic one.
fn now(clock: wasi.clockid_t) ?u64 {
    var ts: wasi.timestamp_t = undefined;
    const err = wasi.clock_time_get(clock, 1, &ts);
    if (err != .SUCCESS) {
        libc.setErrno(err);
        return null;
    }
    return ts;
}

fn time(out: ?*time_t) callconv(.c) time_t {
    const ns = now(.REALTIME) orelse return -1;
    const t: time_t = @intCast(ns / ns_per_s);
    if (out) |p| p.* = t;
    return t;
}

fn gettimeofday(tv: ?*Timeval, tz: ?*anyopaque) callconv(.c) c_int {
    _ = tz;
    const ns = now(.REALTIME) orelse return -1;
    if (tv) |p| p.* = .{
        .tv_sec = @intCast(ns / ns_per_s),
        .tv_usec = @intCast((ns % ns_per_s) / std.time.ns_per_us),
    };
    return 0;
}

/// CLOCK_REALTIME and CLOCK_MONOTONIC in time.h have the same values as their WASI counterparts.
fn clock_gettime(clock: c_int, ts: *Timespec) callconv(.c) c_int {
    const id: wasi.clockid_t = switch (clock) {
        0 => .REALTIME,
        1 => .MONOTONIC,
        else => {
            libc.setErrno(.INVAL);
            return -1;
        },
    };
    const ns = now(id) orelse return -1;
    ts.* = .{ .tv_sec = @intCast(ns / ns_per_s), .tv_nsec = @intCast(ns % ns_per_s) };
    return 0;
}

/// Days since 1970-01-01 for a proleptic Gregorian date.
/// From Howard Hinnant's "chrono-compatible low-level date algorithms".
fn daysFromCivil(year: i64, month: i64, day: i64) i64 {
    const y = if (month <= 2) year - 1 else year;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const mp = if (month > 2) month - 3 else month + 9;
    const doy = @divFloor(153 * mp + 2, 5) + day - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

const Civil = struct { year: i64, month: i64, day: i64 };

fn civilFromDays(days: i64) Civil {
    const z = days + 719468;
    const era = @divFloor(z, 146097);
    const doe = z - era * 146097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const day = doy - @divFloor(153 * mp + 2, 5) + 1;
    const month = if (mp < 10) mp + 3 else mp - 9;
    return .{ .year = yoe + era * 400 + @intFromBool(month <= 2), .month = month, .day = day };
}

fn gmtime_r(t: *const time_t, tm: *Tm) callconv(.c) ?*Tm {
    const days = @divFloor(t.*, s_per_day);
    const secs = @mod(t.*, s_per_day);
    const date = civilFromDays(days);
    const tm_year = std.math.cast(c_int, date.year - 1900) orelse {
        libc.setErrno(.OVERFLOW);
        return null;
    };
    tm.* = .{
        .tm_sec = @intCast(@mod(secs, 60)),
        .tm_min = @intCast(@mod(@divFloor(secs, 60), 60)),
        .tm_hour = @intCast(@divFloor(secs, 3600)),
        .tm_mday = @intCast(date.day),
        .tm_mon = @intCast(date.month - 1),
        .tm_year = tm_year,
        .tm_wday = @intCast(@mod(days + 4, 7)),
        .tm_yday = @intCast(days - daysFromCivil(date.year, 1, 1)),
        .tm_isdst = 0,
        .tm_gmtoff = 0,
        .tm_zone = "UTC",
        .__tm_nsec = 0,
    };
    return tm;
}

var gmtime_result: Tm = undefined;

fn gmtime(t: *const time_t) callconv(.c) ?*Tm {
    return gmtime_r(t, &gmtime_result);
}

/// Out of range fields are normalized, as with mktime().
fn timegm(tm: *Tm) callconv(.c) time_t {
    const month: i64 = tm.tm_mon;
    const year = @as(i64, tm.tm_year) + 1900 + @divFloor(month, 12);
    const days = daysFromCivil(year, @mod(month, 12) + 1, 1) + tm.tm_mday - 1;
    const t = days * s_per_day + @as(i64, tm.tm_hour) * 3600 + @as(i64, tm.tm_min) * 60 + tm.tm_sec;
    if (gmtime_r(&t, tm) == null) return -1;
    return t;
}

fn difftime(a: time_t, b: time_t) callconv(.c) f64 {
    return @floatFromInt(@as(i128, a) - b);
}

/// A freestanding module can't yield to the host, so this busy-waits on the monotonic clock.
fn nanosleep(req: *const Timespec, rem: ?*Timespec) callconv(.c) c_int {
    if (req.tv_sec < 0 or req.tv_nsec < 0 or req.tv_nsec >= ns_per_s) {
        libc.setErrno(.INVAL);
        return -1;
    }
    const duration = @as(u64, @intCast(req.tv_sec)) *| ns_per_s +| @as(u64, @intCast(req.tv_nsec));
    const start = now(.MONOTONIC) orelse return -1;
    while ((now(.MONOTONIC) orelse return -1) -% start < duration) {}
    if (rem) |r| r.* = .{ .tv_sec = 0, .tv_nsec = 0 };
    return 0;
}

fn sleep(seconds: c_uint) callconv(.c) c_uint {
    const req: Timespec = .{ .tv_sec = seconds, .tv_nsec = 0 };
    return if (nanosleep(&req, null) == 0) 0 else seconds;
}

fn usleep(usec: c_uint) callconv(.c) c_int {
    const req: Timespec = .{
        .tv_sec = usec / std.time.us_per_s,
        .tv_nsec = @intCast((usec % std.time.us_per_s) * std.time.ns_per_us),
    };
    return nanosleep(&req, null);
}
