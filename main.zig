const std = @import("std");
const raylib = @import("raylib");

pub fn main() void {
    raylib.initWindow(800, 450, "Gerber Viewer");

    defer raylib.closeWindow();

    while (!raylib.windowShouldClose()) {
        raylib.beginDrawing();
        raylib.clearBackground(.ray_white);
        raylib.drawText("This is a Gerber File Viewer:", 190, 10, 20, .maroon);
        raylib.endDrawing();
    }
}