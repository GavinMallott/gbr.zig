const std = @import("std");
const builtin = std.builtin;

const Delimiters = [_]u8{"*", "%", "\n", " ", "\r", "\t"});
pub fn findFirstDelimiterSIMD(buffer: []const u8, delimiters: []const u8) usize {
    // Use 256-bit vector = 32 bytes
    const chunk_size = 32;
    const len = input.len;

    var i: usize = 0;

    while (i + chunk_size < len) : (i += chunk_size) {
        const chunk = @ptrCast([*]const u8, input[i..i+chunk_size].ptr);
        const vector = @bitCast(__m256i, chunk.*);

        var mask: u32 = 0;

        inline for (delimiters) |delim| {
            const delim_vec = @vector(u8, chunk_size){};
            
