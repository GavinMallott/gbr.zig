const std = @import("std");
const gerber = @import("gerber");

pub fn main() !void {
    gerber.printf("Hello {s}\n", .{"Gavin"});
}
