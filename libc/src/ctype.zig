const std = @import("std");
const ascii = std.ascii;
const symbol = @import("libc.zig").symbol;

comptime {
    symbol(&isalnum, "isalnum");
    symbol(&isalpha, "isalpha");
    symbol(&isascii, "isascii");
    symbol(&isblank, "isblank");
    symbol(&iscntrl, "iscntrl");
    symbol(&isdigit, "isdigit");
    symbol(&isgraph, "isgraph");
    symbol(&islower, "islower");
    symbol(&isprint, "isprint");
    symbol(&ispunct, "ispunct");
    symbol(&isspace, "isspace");
    symbol(&isupper, "isupper");
    symbol(&isxdigit, "isxdigit");
    symbol(&tolower, "tolower");
    symbol(&toupper, "toupper");
}

/// The C locale only knows about ASCII, and EOF must classify as nothing.
fn classify(comptime predicate: fn (u8) bool, c: c_int) c_int {
    const byte = std.math.cast(u8, c) orelse return 0;
    return @intFromBool(predicate(byte));
}

fn isalnum(c: c_int) callconv(.c) c_int {
    return classify(ascii.isAlphanumeric, c);
}

fn isalpha(c: c_int) callconv(.c) c_int {
    return classify(ascii.isAlphabetic, c);
}

fn isascii(c: c_int) callconv(.c) c_int {
    return @intFromBool(c >= 0 and c < 0x80);
}

fn isBlank(c: u8) bool {
    return c == ' ' or c == '\t';
}

fn isblank(c: c_int) callconv(.c) c_int {
    return classify(isBlank, c);
}

fn iscntrl(c: c_int) callconv(.c) c_int {
    return classify(ascii.isControl, c);
}

pub fn isdigit(c: c_int) callconv(.c) c_int {
    return classify(ascii.isDigit, c);
}

fn isgraph(c: c_int) callconv(.c) c_int {
    return classify(ascii.isGraphical, c);
}

fn islower(c: c_int) callconv(.c) c_int {
    return classify(ascii.isLower, c);
}

fn isprint(c: c_int) callconv(.c) c_int {
    return classify(ascii.isPrint, c);
}

fn ispunct(c: c_int) callconv(.c) c_int {
    return classify(ascii.isPunctuation, c);
}

pub fn isspace(c: c_int) callconv(.c) c_int {
    return classify(ascii.isWhitespace, c);
}

fn isupper(c: c_int) callconv(.c) c_int {
    return classify(ascii.isUpper, c);
}

fn isxdigit(c: c_int) callconv(.c) c_int {
    return classify(ascii.isHex, c);
}

pub fn tolower(c: c_int) callconv(.c) c_int {
    const byte = std.math.cast(u8, c) orelse return c;
    return ascii.toLower(byte);
}

fn toupper(c: c_int) callconv(.c) c_int {
    const byte = std.math.cast(u8, c) orelse return c;
    return ascii.toUpper(byte);
}
