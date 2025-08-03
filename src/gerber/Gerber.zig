const std = @import("std");
const gerber = @import("../gerber.zig");

const Aperture = gerber.Aperture;
const Token = gerber.Token;
const Tokenizer = gerber.Tokenizer;
const GBRError = gerber.GBRError;

pub const Gerber = @This();

meta: Meta,

apertures: std.ArrayList(Aperture),
macro_names: std.ArrayList([]const u8),

comments: std.ArrayList([]const u8),

commands: std.ArrayList(Command),
//index: usize,

//attributes: std.ArrayList(Attribute),

const Meta = struct {
    mode: Mode, 
    polarity: Polarity, 
    rotation: u8,
    scale: f64,
    mirror: Mirror,
    lcr: LCR, format: Format, 
    cursor: Cursor, 
    active_aperture: usize,
};


pub const Mode = enum {MM, IN};
pub const Polarity = enum {DARK, CLEAR};
pub const Mirror = enum {X, Y, XY, NONE}; 
pub const Cursor = struct {x: f64, y: f64};
pub const Format = struct {X_1: u8, X_2: u8, Y_1: u8, Y_2: u8};
pub const LCR = enum {LINEAR, CIRCULAR, ARC};
pub const Command = struct {cmd: Token.Tag, x: f64, y: f64, meta: Meta};
pub const Attribute = struct {data: []const u8};

pub fn processFile(file: [:0]const u8, allocator: std.mem.Allocator) GBRError!Gerber {
    var mode: Mode = undefined;
    var format: Format = undefined;
    var lcr: LCR = undefined;
    var cursor: Cursor = .{.x = 0.0, .y = 0.0};
    var polarity: Polarity = .DARK;
    var rotation: u8 = 0.0;
    var scale: f64 = 1;
    var mirror: Mirror = .NONE;
    var active_aperture: usize = 0;
    var apertures = std.ArrayList(Aperture).init(allocator);
    var macro_names = std.ArrayList([]const u8).init(allocator);
    var comments = std.ArrayList([]const u8).init(allocator);
    var commands = std.ArrayList(Command).init(allocator);
    //var file_attributes = std.ArrayList(Attribute).init(allocator);
    //var ap_attributes = std.ArrayList(Attribute).init(allocator);
    //var object_attributes = std.ArrayList(Attribute).init(allocator);

    var tokens = Tokenizer.init(file);
    while(tokens.next()) |t| {
        switch (t.tag) {
            .mode => {
                const mode_str = tokens.buffer[t.loc.start..t.loc.end];
                if (std.mem.eql(u8, mode_str, "MM")) {
                    mode = .MM;
                } else if (std.mem.eql(u8, mode_str, "IN")) {
                    mode = .IN;
                } else {
                    return GBRError.InvalidParameters;
                }
            },
            .format => {
                const format_str = tokens.buffer[t.loc.start..t.loc.end];
                var X1: u8 = undefined;
                var X2: u8 = undefined;
                var Y1: u8 = undefined;
                var Y2: u8 = undefined;

                if (std.mem.startsWith(u8, format_str, "X")) {
                    X1 = try std.fmt.parseInt(u8, format_str[1..2], 10);
                    X2 = try std.fmt.parseInt(u8, format_str[2..3], 10);
                    Y1 = try std.fmt.parseInt(u8, format_str[4..5], 10);
                    Y2 = try std.fmt.parseInt(u8, format_str[5..], 10);
                } else if (std.mem.startsWith(u8, format_str, "Y")) {
                    Y1 = try std.fmt.parseInt(u8, format_str[1..2], 10);
                    Y2 = try std.fmt.parseInt(u8, format_str[2..3], 10);
                    X1 = try std.fmt.parseInt(u8, format_str[4..5], 10);
                    X2 = try std.fmt.parseInt(u8, format_str[5..], 10);
                } else {
                    return GBRError.InvalidParameters;
                }

                format.X_1 = X1;
                format.X_2 = X2;
                format.Y_1 = Y1;
                format.Y_2 = Y2;
            },
            .step_repeat => {},
            .load_polarity => {
                const polarity_str = tokens.buffer[t.loc.start..t.loc.end];
                if (std.mem.eql(u8, polarity_str, "D")) {
                    polarity = .DARK;
                } else if (std.mem.eql(u8, polarity_str, "C")) {
                    polarity = .CLEAR;
                } else {
                    return GBRError.InvalidParameters;
                }
            },
            .load_scale => {
                const ls_str = tokens.buffer[t.loc.start..t.loc.end];
                const ls = try std.fmt.parseFloat(f64, ls_str);
                scale = ls;
            }, 
            .load_mirror => {
                const lm_str = tokens.buffer[t.loc.start..t.loc.end];
                if (std.mem.eql(u8, lm_str, "X")) {
                    mirror = .X;
                } else if (std.mem.eql(u8, lm_str, "Y")) {
                    mirror = .Y;
                } else if (std.mem.eql(u8, lm_str, "XY")) {
                    mirror = .XY;
                } else if (std.mem.eql(u8, lm_str, "NONE")) {
                    mirror = .NONE;
                } else {
                    return GBRError.InvalidParameters;
                }
            }, 
            .load_rotation => {
                const lr_str = tokens.buffer[t.loc.start..t.loc.end];
                const lr = try std.fmt.parseInt(u8, lr_str, 10);
                rotation = lr;
            },
            .linear_mode => lcr = .LINEAR,
            .circular_mode => lcr = .CIRCULAR,
            .arc_mode => lcr = .ARC,
            .comment => {
                const comment = tokens.buffer[t.loc.start..t.loc.end];
                try comments.append(comment);
            },
            .ap_set => {
                const ap_name = tokens.buffer[t.loc.start..t.loc.end];
                for (apertures.items, 0..) |ap, i| {
                    if (std.mem.eql(u8, ap_name, ap.id)) {
                        active_aperture = i;
                    }
                }
            },
            .ap_define => {
                const ap_str = tokens.buffer[t.loc.start..t.loc.end];

                var ap_name_end: usize = 1;
                for(ap_str[1..]) |char| {
                    if (std.ascii.isDigit(char)) {
                        ap_name_end += 1;
                    } else break;
                }
                const ap_name = ap_str[0..ap_name_end];


                const ap_type_str = ap_str[ap_name_end..ap_name_end+1];
                const ap_params = ap_str[ap_name_end+1..];
                var ap: Aperture = undefined;
                ap.id = ap_name;
                ap.attributes = null;

                var macro_found: bool = false;

                for (macro_names.items) |macro| {
                    
                    if (std.mem.eql(u8, macro, ap_str[3..])) {
                        const mAP: Aperture.MacroAperture = .{
                            .data = ap_str[ap_name_end..],
                        };
                        ap.ap = .{ .M = mAP };
                        macro_found = true;
                    }
                }
                if (!macro_found) {
                    if (std.mem.eql(u8, ap_type_str, "C")) {
                        const floats = try fivePossibleFloats(ap_params);
                        const diameter = floats[0].?;
                        var hole_diam: ?f64 = null;
                        if (floats[1] != null) {
                            hole_diam = floats[1].?;
                        }
                        
                        const cAP: Aperture.CircleAperture = .{
                            .diameter = diameter,
                            .hole_diam = hole_diam,
                        };
                        ap.ap = .{ .C = cAP };
                    } else if (std.mem.eql(u8, ap_type_str, "R")) {
                        const floats = try fivePossibleFloats(ap_params);
                        const x_size = floats[0].?;
                        const y_size = floats[1].?;
                        var hole_diam: ?f64 = null;
                        if (floats[2] != null) {
                            hole_diam = floats[2].?;
                        }
                        
                        const rAP: Aperture.RectAperture = .{
                            .x = x_size,
                            .y = y_size,
                            .hole_diam = hole_diam,
                        };
                        ap.ap = .{ .R = rAP };
                    } else if (std.mem.eql(u8, ap_type_str, "O")) {
                        const floats = try fivePossibleFloats(ap_params);
                        const x_size = floats[0].?;
                        const y_size = floats[1].?;
                        var hole_diam: ?f64 = null;
                        if (floats[2] != null) {
                            hole_diam = floats[2].?;
                        }
                        
                        const oAP: Aperture.ObroundAperture = .{
                            .x = x_size,
                            .y = y_size,
                            .hole_diam = hole_diam,
                        };
                        ap.ap = .{ .O = oAP };
                    } else if (std.mem.eql(u8, ap_type_str, "P")) {
                        const floats = try fivePossibleFloats(ap_params);
                        const outer_diameter = floats[0].?;
                        const verticies = floats[1].?;
                        const ap_rotation = floats[2].?;
                        var hole_diam: ?f64 = null;
                        if (floats[3] != null) {
                            hole_diam = floats[3].?;
                        }
                        
                        const pAP: Aperture.PolygonAperture = .{
                            .outer_diam = outer_diameter,
                            .verticies = verticies,
                            .rotation = ap_rotation,
                            .hole_diam = hole_diam,
                        };
                        ap.ap = .{ .P = pAP};
                    } else {
                        return GBRError.InvalidParameters;
                    }
                }

                try apertures.append(ap);
            },
            .ap_macro => {
                const macro_name = tokens.buffer[t.loc.start..t.loc.end];
                try macro_names.append(macro_name);

            },
            .macro_item => {

            },
            .ap_block => {

            },
            .ap_block_end => {

            },
            .start_region, .end_region => {},
            .move => {
                const cmd_str = tokens.buffer[t.loc.start..t.loc.end];
                var x: f64 = cursor.x;
                var y: f64 = cursor.y;
                
                var coord_it = std.mem.tokenizeAny(u8, cmd_str, "XY");
                    if (coord_it.next()) |coord1| {
                        var tmp_buf: [256]u8 = undefined;
                        const int_len = format.X_1;

                        std.mem.copyForwards(u8, &tmp_buf, coord1[0..int_len]);
                        tmp_buf[int_len] = 46;
                        std.mem.copyForwards(u8, tmp_buf[int_len+1..int_len+coord1.len+1], coord1[int_len..]);
                        x = try std.fmt.parseFloat(f64, tmp_buf[0..coord1.len+1]);

                        if (coord_it.next()) |coord2| {
                            tmp_buf = undefined;
                            std.mem.copyForwards(u8, &tmp_buf, coord2[0..int_len]);
                            tmp_buf[int_len] = 46;
                            std.mem.copyForwards(u8, tmp_buf[int_len+1..int_len+coord2.len+1], coord2[int_len..]);

                            y = try std.fmt.parseFloat(f64, tmp_buf[0..coord2.len+1]);
                        }
                    }
                cursor.x = x;
                cursor.y = y;
                const cmd: Command = .{
                    .x = x,
                    .y = y,
                    .cmd = .move,
                    .meta = .{
                        .mode = mode,
                        .format = format,
                        .lcr = lcr,
                        .polarity = polarity,
                        .scale = scale,
                        .rotation = rotation,
                        .mirror = mirror,
                        .active_aperture = active_aperture,
                        .cursor = cursor,
                    },
                };

                try commands.append(cmd);
            },
            .plot => {
                const cmd_str = tokens.buffer[t.loc.start..t.loc.end];
                var x: f64 = cursor.x;
                var y: f64 = cursor.y;
                
                var coord_it = std.mem.tokenizeAny(u8, cmd_str, "XY");
                    if (coord_it.next()) |coord1| {
                        var tmp_buf: [256]u8 = undefined;
                        const int_len = format.X_1;

                        std.mem.copyForwards(u8, &tmp_buf, coord1[0..int_len]);
                        tmp_buf[int_len] = 46;
                        std.mem.copyForwards(u8, tmp_buf[int_len+1..int_len+coord1.len+1], coord1[int_len..]);
                        x = try std.fmt.parseFloat(f64, tmp_buf[0..coord1.len+1]);

                        if (coord_it.next()) |coord2| {
                            tmp_buf = undefined;
                            std.mem.copyForwards(u8, &tmp_buf, coord2[0..int_len]);
                            tmp_buf[int_len] = 46;
                            std.mem.copyForwards(u8, tmp_buf[int_len+1..int_len+coord2.len+1], coord2[int_len..]);

                            y = try std.fmt.parseFloat(f64, tmp_buf[0..coord2.len+1]);
                        }
                    }

                const cmd: Command = .{
                    .x = x,
                    .y = y,
                    .cmd = .plot,
                    .meta = .{
                        .mode = mode,
                        .format = format,
                        .lcr = lcr,
                        .polarity = polarity,
                        .scale = scale,
                        .rotation = rotation,
                        .mirror = mirror,
                        .active_aperture = active_aperture,
                        .cursor = cursor,
                    },
                };

                try commands.append(cmd);
            },
            .flash => {
                const cmd_str = tokens.buffer[t.loc.start..t.loc.end];
                var x: f64 = cursor.x;
                var y: f64 = cursor.y;
                
                var coord_it = std.mem.tokenizeAny(u8, cmd_str, "XY");
                    if (coord_it.next()) |coord1| {
                        var tmp_buf: [256]u8 = undefined;
                        const int_len = format.X_1;

                        std.mem.copyForwards(u8, &tmp_buf, coord1[0..int_len]);
                        tmp_buf[int_len] = 46;
                        std.mem.copyForwards(u8, tmp_buf[int_len+1..int_len+coord1.len+1], coord1[int_len..]);
                        x = try std.fmt.parseFloat(f64, tmp_buf[0..coord1.len+1]);

                        if (coord_it.next()) |coord2| {
                            tmp_buf = undefined;
                            std.mem.copyForwards(u8, &tmp_buf, coord2[0..int_len]);
                            tmp_buf[int_len] = 46;
                            std.mem.copyForwards(u8, tmp_buf[int_len+1..int_len+coord2.len+1], coord2[int_len..]);

                            y = try std.fmt.parseFloat(f64, tmp_buf[0..coord2.len+1]);
                        }
                    }

                const cmd: Command = .{
                    .x = x,
                    .y = y,
                    .cmd = .flash,
                    .meta = .{
                        .mode = mode,
                        .format = format,
                        .lcr = lcr,
                        .polarity = polarity,
                        .scale = scale,
                        .rotation = rotation,
                        .mirror = mirror,
                        .active_aperture = active_aperture,
                        .cursor = cursor,
                    },
                };

                try commands.append(cmd);
            },
            .file_attribute, .ap_attribute, .object_attribute, .delete_attribute => {},
            .G75, .eof => {},
        }
    }

    return Gerber{
        .meta = .{
            .polarity = polarity,
            .scale = scale,
            .rotation = rotation,
            .mirror = mirror,
            .mode = mode,
            .format = format,
            .lcr = lcr,
            .cursor = cursor,
            .active_aperture = active_aperture,
        },
        .comments = comments,
        .apertures = apertures,
        .macro_names = macro_names,
        .commands = commands,
    };
}

pub fn deinit(self: *Gerber) void {
    self.apertures.deinit();
    self.comments.deinit();
    self.commands.deinit();
    self.macro_names.deinit();
}

pub fn disp(self: *Gerber) void {
    std.debug.print("Gerber File:\n", .{});
    std.debug.print("   Polarity: {s}\n", .{@tagName(self.meta.polarity)});
    std.debug.print("   Rotation: {d}\n", .{self.meta.rotation});
    std.debug.print("   Scale: {d}\n", .{self.meta.scale});
    std.debug.print("   Mirror: {s}\n", .{@tagName(self.meta.mirror)});
    std.debug.print("   Mode: {s}\n", .{@tagName(self.meta.mode)});
    std.debug.print("   LCR: {s}\n", .{@tagName(self.meta.lcr)});
    std.debug.print("   Format: X: {d}.{d}, Y: {d}.{d}\n", .{self.meta.format.X_1, self.meta.format.X_2, self.meta.format.Y_1, self.meta.format.Y_2});
    std.debug.print("Current Cursor: {d},{d}\n", .{self.meta.cursor.x, self.meta.cursor.y});
    std.debug.print("Comments:\n", .{});
    for (self.comments.items) |cmt| {
        std.debug.print("   --{s}\n", .{cmt});
    }
    std.debug.print("Apertures:\n", .{});
    for (self.apertures.items) |ap| {
        ap.disp();
    }
    std.debug.print("Active Aperture: {s}\n", .{self.apertures.items[self.meta.active_aperture].id});
    std.debug.print("Commands:\n", .{});
    for (self.commands.items) |cmd| {
        std.debug.print("   --{s}: {d},{d} with {s}\n", .{@tagName(cmd.cmd), cmd.x, cmd.y, self.apertures.items[cmd.meta.active_aperture].id});
    }
}

fn fivePossibleFloats(buf: []const u8) GBRError![5]?f64 {
    var f1: ?f64 = null;
    var f2: ?f64 = null;
    var f3: ?f64 = null;
    var f4: ?f64 = null;
    var f5: ?f64 = null;
    var i: usize = 0;

    var float_it = std.mem.tokenizeAny(u8, buf, ",XY");

    //std.debug.print("Parsing floats from: {s}\n", .{buf});

    while(float_it.next()) |num_str| {
        i += 1;
        //std.debug.print("Float #{d}: {s}\n", .{i, num_str});
        if (f1 == null) {
            f1 = try std.fmt.parseFloat(f64, num_str);
        } else if (f2 == null) {
            f2 = try std.fmt.parseFloat(f64, num_str);
        } else if (f3 == null) {
            f3 = try std.fmt.parseFloat(f64, num_str);
        } else if (f4 == null) {
            f4 = try std.fmt.parseFloat(f64, num_str);
        } else if (f5 == null) {
            f5 = try std.fmt.parseFloat(f64, num_str);
        }
    }

    const floats = [5]?f64 {f1, f2, f3, f4, f5};
    return floats;
}