const std = @import("std");

pub const Gerber = @import("gerber/Gerber.zig");
pub const Aperture = @import("gerber/Aperture.zig");
pub const gbr_tokens = @import("gerber/tokenizer.zig");
pub const Attribute = Gerber.Attribute;
pub const Token = gbr_tokens.Token;
pub const Tokenizer = gbr_tokens.Tokenizer;
pub const GBRError = gbr_tokens.GBRError;

pub const gexample = @embedFile("gbr_example.gbr");


test "Tokenizer" {
    std.debug.print("### BEGIN Debug TEST ###\n", .{});
    var tk = Tokenizer.init(gexample);
    //std.debug.print("example[322..] = {s}\n", .{gexample[322..]});
    tk.debug();
    std.debug.print("\n", .{});
}

test "Gerber" {
    std.debug.print("### BEGIN Gerber TEST ###\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const ally = gpa.allocator();
    defer _ = gpa.deinit();

    var G1 = try Gerber.processFile(gexample, ally);
    defer G1.deinit();

    G1.disp();

    std.debug.print("\n", .{});
}