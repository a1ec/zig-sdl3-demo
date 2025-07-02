const c = @import("cimports.zig").c;

pub const sprites = struct {
    pub const bmp = @embedFile("sprites.bmp");

    // zig fmt: off
    pub const brick_2x1_purple: c.SDL_FRect = .{ .x =   1, .y =  1, .w = 64, .h = 32 };
    pub const brick_1x1_purple: c.SDL_FRect = .{ .x =  67, .y =  1, .w = 32, .h = 32 };
    pub const brick_2x1_red:    c.SDL_FRect = .{ .x = 101, .y =  1, .w = 64, .h = 32 };
    pub const brick_1x1_red:    c.SDL_FRect = .{ .x = 167, .y =  1, .w = 32, .h = 32 };
    pub const brick_2x1_yellow: c.SDL_FRect = .{ .x =   1, .y = 35, .w = 64, .h = 32 };
    pub const brick_1x1_yellow: c.SDL_FRect = .{ .x =  67, .y = 35, .w = 32, .h = 32 };
    pub const brick_2x1_green:  c.SDL_FRect = .{ .x = 101, .y = 35, .w = 64, .h = 32 };
    pub const brick_1x1_green:  c.SDL_FRect = .{ .x = 167, .y = 35, .w = 32, .h = 32 };
    pub const brick_2x1_blue:   c.SDL_FRect = .{ .x =   1, .y = 69, .w = 64, .h = 32 };
    pub const brick_1x1_blue:   c.SDL_FRect = .{ .x =  67, .y = 69, .w = 32, .h = 32 };
    pub const brick_2x1_gray:   c.SDL_FRect = .{ .x = 101, .y = 69, .w = 64, .h = 32 };
    pub const brick_1x1_gray:   c.SDL_FRect = .{ .x = 167, .y = 69, .w = 32, .h = 32 };

    pub const ball:   c.SDL_FRect = .{ .x =  2, .y = 104, .w =  22, .h = 22 };
    pub const paddle: c.SDL_FRect = .{ .x = 27, .y = 103, .w = 104, .h = 24 };
    // zig fmt: on
};
