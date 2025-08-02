const std = @import("std");
const gerber = @import("../gerber.zig");
const Attribute = gerber.Attribute;

pub const Aperture = @This();

id: []const u8,
ap: AptertureType,
attributes: ?[]Attribute,

pub const CircleAperture = struct {
    diameter: f64,
    hole_diam: ?f64,
};

pub const RectAperture = struct {
    x: f64,
    y: f64,
    hole_diam: ?f64,
};

pub const ObroundAperture = struct {
    x: f64,
    y: f64,
    hole_diam: ?f64,
};

pub const PolygonAperture = struct {
    outer_diam: f64,
    verticies: f64,
    rotation: f64,
    hole_diam: ?f64,
};

pub const MacroAperture = struct {
    data: []const u8,
};

pub const AptertureType = union(enum) {
    C: CircleAperture,
    R: RectAperture,
    O: ObroundAperture,
    P: PolygonAperture,
    M: MacroAperture,
};

pub fn disp(self: *const Aperture) void {
    switch (self.ap) {
        .C => {
            std.debug.print("Circle: {s}\n", .{self.id});
            std.debug.print("   --Diameter: {d}\n", .{self.ap.C.diameter});
            if (self.ap.C.hole_diam != null) {
                std.debug.print("   --Hole Diameter: {d}\n", .{self.ap.C.hole_diam.?});
            }
        },
        .R => {
            std.debug.print("Rectangle: {s}\n", .{self.id});
            std.debug.print("   --X_Size: {d}\n", .{self.ap.R.x});
            std.debug.print("   --Y_Size: {d}\n", .{self.ap.R.y});
            if (self.ap.R.hole_diam != null) {
                std.debug.print("   --Hole Diameter: {d}\n", .{self.ap.R.hole_diam.?});
            }
        },
        .O => {
            std.debug.print("Obround: {s}\n", .{self.id});
            std.debug.print("   --X_Size: {d}\n", .{self.ap.O.x});
            std.debug.print("   --Y_Size: {d}\n", .{self.ap.O.y});
            if (self.ap.O.hole_diam != null) {
                std.debug.print("   --Hole Diameter: {d}\n", .{self.ap.O.hole_diam.?});
            }
        },
        .P => {
            std.debug.print("Polygon: {s}\n", .{self.id});
            std.debug.print("   --Outer Diameter: {d}\n", .{self.ap.P.outer_diam});
            std.debug.print("   --Verticies: {d}\n", .{self.ap.P.verticies});
            std.debug.print("   --Rotation: {d}\n", .{self.ap.P.rotation});
            if (self.ap.P.hole_diam != null) {
                std.debug.print("   --Hole Diameter: {d}\n", .{self.ap.P.hole_diam.?});
            }
        },
        .M => {
            std.debug.print("Macro: {s}\n", .{self.id});
            std.debug.print("   --{s}\n", .{self.ap.M.data});
        }
    }
}