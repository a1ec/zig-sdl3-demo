const c = @import("cimports.zig").c;
const Point = @import("Point.zig");

pub fn getMousePosition(x: *f32, y: *f32, scale: f32) Point {
    _ = c.SDL_GetMouseState(x, y);
    return .{ .x = x.* / scale, .y = y.* / scale };
}
