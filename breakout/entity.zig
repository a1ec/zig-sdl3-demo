const c = @import("cimports.zig").c;

pub const player = [_]c.SDL_Vertex{
    .{ .position = .{ .x = 40, .y = 20 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
    .{ .position = .{ .x = 30, .y = 40 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
    .{ .position = .{ .x = 50, .y = 40 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
};
