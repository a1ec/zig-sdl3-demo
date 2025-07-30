const c = @import("cimports.zig").c;
const Point = @import("Point.zig");

pub fn getMousePosition(scale: f32) Point {
    var x: f32 = undefined;
    var y: f32 = undefined;

    _ = c.SDL_GetMouseState(&x, &y);
    return .{ .x = x / scale, .y = y / scale };
}
