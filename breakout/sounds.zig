pub const sounds = struct {
    pub const wav = @embedFile("sounds.wav");

    // zig fmt: off
    pub const hit_wall   = .{      0,  4_886 };
    pub const hit_paddle = .{  4_886, 17_165 };
    pub const hit_brick  = .{ 17_165, 25_592 };
    pub const win        = .{ 25_592, 49_362 };
    pub const lose       = .{ 49_362, 64_024 };
    // zig fmt: on
};


