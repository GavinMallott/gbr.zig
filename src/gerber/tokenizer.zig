const std = @import("std");
const gerber = @import("../gerber.zig");

pub const GBRError = error{
    MissingNewline,
    MissingStar,
    MissingPercent,
    InvalidParameters,
    Unexpected,

    OutOfMemory,
    Overflow,
    InvalidCharacter,
};

pub const Token = struct {
    tag: Tag,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{"%", .percent},
        .{"*", .star},
        .{"G04", .comment},
        .{"MO", .mode},
        .{"FSLA", .format},
        .{"AD", .ap_define},
        .{"AM", .ap_macro},
        .{"D1", .ap_set},
        .{"D01", .plot},
        .{"D02", .move},
        .{"D03", .flash},
        .{"G75", .arc_mode},
        .{"G36", .start_region},
        .{"G37", .end_region},
        .{"LP", .load_polarity},
        .{"LM", .load_mirror},
        .{"LR", .load_rotation},
        .{"LS", .load_scale},
        .{"AB", .ap_block},
        .{"SR", .step_repeat},
        .{"TF", .file_attribute},
        .{"TA", .ap_attribute},
        .{"TO", .object_attribute},
        .{"TD", .delete_attribute},
        .{"M02", .eof},
    });

    pub fn getKeywords(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }

    pub const Tag = enum {
        comment,
        mode,
        format,
        ap_define,
        ap_macro,
        macro_item,
        ap_set,
        plot,
        move,
        flash,
        linear_mode,
        circular_mode,
        arc_mode,
        G75,
        load_polarity,
        load_mirror,
        load_rotation,
        load_scale,
        start_region,
        end_region,
        ap_block,
        ap_block_end,
        step_repeat,
        file_attribute,
        ap_attribute,
        object_attribute,
        delete_attribute,
        eof,
    };  
};

pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: usize,

    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debut.print("{s} \"{s}\"\n", .{ @tagName(token.tag), self.buffer[token.loc.start .. token.loc.end] });
    }

    pub fn init(buffer: [:0]const u8) Tokenizer {
        return .{
            .buffer = buffer,
            .index = 0,
        };
    }

    const State = enum {
        start,

        expect_newline,
        expect_percent,
        expect_star,

        M02,
        G01,
        G02,
        G03,
        G04,
        MO,
        FSLA,
        LP,
        LR,
        LM,
        LS,
        SR,

        COORD,
        D,
        AB,
        ABEnd,
        G36,
        G37,
        G75,

        AD,
        AM,
        macro_item,
        TF,
        TA,
        TO,
        TD,

        Text,

        invalid,
    };

    pub fn next(self: *Tokenizer) ?Token {
        var result: Token = .{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = undefined,
            }
        };
        state: switch (State.start) {
            .start => { 
                if (std.mem.startsWith(u8, self.buffer[self.index..], "G04 ")) {
                    self.index += 4;
                    continue :state .G04;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "G01")) {
                    self.index += 3;
                    continue :state .G01;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "G02")) {
                    self.index += 3;
                    continue :state .G02;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "G03")) {
                    self.index += 3;
                    continue :state .G03;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "G36")) {
                    self.index += 3;
                    continue :state .G36;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "G37")) {
                    self.index += 3;
                    continue :state .G37;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "G75")) {
                    self.index += 3;
                    continue :state .G75;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "X")) {
                    continue :state .COORD;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "Y")) {
                    continue :state .COORD;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "D")) {
                    continue :state .D;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "M02*")) {
                    self.index += 4;
                    continue :state .M02;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%MO")) {
                    self.index += 3;
                    continue :state .MO;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%AD")) {
                    self.index += 3;
                    continue :state .AD;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%AM")) {
                    self.index += 3;
                    continue :state .AM;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%AB")) {
                    self.index += 3;
                    continue :state .AB;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%FSLA")) {
                    self.index += 5;
                    continue :state .FSLA;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%SR")) {
                    self.index += 3;
                    continue :state .SR;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%LS")) {
                    self.index += 3;
                    continue :state .LS;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%LP")) {
                    self.index += 3;
                    continue :state .LP;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%LM")) {
                    self.index += 3;
                    continue :state .LM;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%LR")) {
                    self.index += 3;
                    continue :state .LR;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%TF")) {
                    self.index += 3;
                    continue :state .TF;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%TO")) {
                    self.index += 3;
                    continue :state .TO;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%TA")) {
                    self.index += 3;
                    continue :state .TA;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%TD")) {
                    self.index += 3;
                    continue :state .TD;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "\r\n")) {
                    self.index += 2;
                    continue :state .start;
                }  else if (std.mem.startsWith(u8, self.buffer[self.index..], "\n")) {
                    self.index += 1;
                    continue :state .start;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "%")) {
                    continue :state .ABEnd;
                } else if (std.ascii.isDigit(self.buffer[self.index])) {
                    continue :state .macro_item;
                } else {
                    return null;
                }
            },
            .G04 => {
                result.tag = .comment;
                const comment_len = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.start = self.index;
                result.loc.end = self.index + comment_len;
                self.index += comment_len;
                continue :state .expect_star;
            },
            .G01 => {
                result.tag = .linear_mode;
                result.loc.start = self.index;
                result.loc.end = self.index;
                continue :state .expect_star;
            },
            .G02 => {
                result.tag = .circular_mode;
                result.loc.start = self.index;
                result.loc.end = self.index;
                continue :state .expect_star;
            },
            .G03 => {
                result.tag = .arc_mode;
                result.loc.start = self.index;
                result.loc.end = self.index;
                continue :state .expect_star;
            },
            .G36 => {
                result.tag = .start_region;
                result.loc.start = self.index;
                result.loc.end = self.index;
                continue :state .expect_star;
            },
            .G37 => {
                result.tag = .end_region;
                result.loc.start = self.index;
                result.loc.end = self.index;
                continue :state .expect_star;
            },
            .G75 => {
                result.tag = .G75;
                result.loc.start = self.index;
                result.loc.end = self.index;
                continue :state .expect_percent;
            },
            .COORD => {
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                const sd = self.buffer[self.index+sl-3..self.index+sl];
                result.loc.start = self.index;
                result.loc.end = self.index + sl - 3;
                self.index += sl;
                if (std.mem.eql(u8, sd, "D01")) {
                    result.tag = .plot;
                    continue :state .expect_star;
                } else if (std.mem.eql(u8, sd, "D02")) {
                    result.tag = .move;
                    continue :state .expect_star;
                } else if (std.mem.eql(u8, sd, "D03")) {
                    result.tag = .flash;
                    continue :state .expect_star;
                } else {
                    continue :state .invalid;
                }
            },
            .D => {
                result.tag = .ap_set;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.start = self.index;
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .M02 => {
                result.tag = .eof;
                result.loc.start = self.index;
                result.loc.end = self.index;
                return result;
            },

            .MO => {
                result.tag = .mode;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .FSLA => {
                result.tag = .format;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .AD => {
                result.tag = .ap_define;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .AM => {
                result.tag = .ap_macro;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .macro_item => {
                result.tag = .macro_item;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .AB => {
                result.tag = .ap_block;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .ABEnd => {
                result.tag = .ap_block_end;
                result.loc.start = self.index;
                result.loc.end = self.index;
                self.index += 1;
                continue :state .expect_newline;
            },
            .SR => {
                result.tag = .step_repeat;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .LP => {
                result.tag = .load_polarity;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .LR => {
                result.tag = .load_rotation;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .LM => {
                result.tag = .load_mirror;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .LS => {
                result.tag = .load_scale;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .TF => {
                result.tag = .file_attribute;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .TA => {
                result.tag = .ap_attribute;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .TO => {
                result.tag = .object_attribute;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .TD => {
                result.tag = .delete_attribute;
                result.loc.start = self.index;
                const sl = lengthUntilStarL(self.buffer[self.index..]);
                result.loc.end = self.index + sl;
                self.index += sl;
                continue :state .expect_star;
            },
            .expect_star => {
                self.index += 1;
                if ((result.tag == .ap_block) or
                    (result.tag == .ap_define) or
                    (result.tag == .ap_macro) or
                    (result.tag == .format) or
                    (result.tag == .mode) or
                    (result.tag == .load_rotation) or
                    (result.tag == .load_mirror) or
                    (result.tag == .load_polarity) or
                    (result.tag == .load_scale) or
                    (result.tag == .file_attribute) or
                    (result.tag == .ap_attribute) or
                    (result.tag == .object_attribute) or
                    (result.tag == .delete_attribute) or
                    (result.tag == .step_repeat)) {
                        continue :state .expect_percent;
                    } else {
                        continue :state .expect_newline;
                    }
            },
            .expect_percent => {
                if (std.mem.startsWith(u8, self.buffer[self.index..], "%")) {
                    self.index += 1;
                    continue :state .expect_newline;
                } else {
                    return null;
                }
            },
            .expect_newline => {
                if (std.mem.startsWith(u8, self.buffer[self.index..], "\r\n")) {
                    self.index += 2;
                    return result;
                } else if (std.mem.startsWith(u8, self.buffer[self.index..], "\n")) {
                    self.index += 1;
                    return result;
                } else {
                    continue :state .invalid;
                }
            },
            .invalid => return null,
            else => continue :state .invalid,
        }

        return result;
    }

    pub fn debug(self: *Tokenizer) void {
        std.debug.print("Deubgging...\n", .{});
        std.debug.print("File:\n{s}\n\n", .{self.buffer[0..]});

        std.debug.print("\nTokenizing:\n", .{});
        while(self.next()) |token| {
            const tag_str = @tagName(token.tag);
            std.debug.print("Tag: {s}\n", .{tag_str});
            //std.debug.print("Printing buffer from: {d},{d}\n", .{token.loc.start,token.loc.end});
            const param = self.buffer[token.loc.start..token.loc.end];
            std.debug.print("Val: {s}\n\n", .{param});

            if (token.tag == .eof) {
                break;
            }
        }

        std.debug.print("Remaining[{d}..]: {s}\n", .{self.index,self.buffer[self.index..]});
    }
};

fn extractUntilStarL(buffer: [:0]const u8, index: usize) []const u8 {
    if (index >= buffer.len) return "";

    var i: usize = index;
    while (i < buffer.len) : (i += 1) {
        if (buffer[i] == 42) {
            return buffer[index..i];
        }
    }

    return "";
}

fn lengthUntilStarL(buffer: [:0]const u8) usize {
    if (buffer.len < 1) return 0;

    var i: usize = 0;
    while (i < buffer.len) : (i += 1) {
        if (buffer[i] == 42) {
            return i;
        }
    }

    return 0;
}
