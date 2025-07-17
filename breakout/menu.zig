const std = @import("std");
const c = @import("cimports.zig").c;

const GameMenu = struct {

    Self = @This(),
    currentIndex: usize = 0,

    pub const Item = enum(u8) {
        NewGame,
        ResumeGame,
        ExitApp,

        pub fn label(self: Item) []const u8 {
            return switch (self) {
                .NewGame => "New Game",
                .ResumeGame => "Resume Game",
                .Exit => "Exit",
            };
        }
    };

    pub const allItems = std.meta.enumValues(Item);
    const textHeight = 12;

    const selectionRect: c.SDL_FRect = .{
        .x = 0,
        .y = 0,
        .w = 320,
        .h = textHeight,
    };

    pub fn moveSelection(self: *Self, direction: f32) void {
        const count = self.allItems.len;
        const next = (@intCast(isize, self.currentIndex) + direction) % (@intCast(isize, count));
        self.currentIndex = @intCast(usize, if (next >= 0) next else next + @intCast(isize, count));
        self.currentIndex %= count; 
    }

    pub fn getSelection(self: *Self) (usize, []const u8) {
        const idx = self.currentIndex;
        return (idx, allItems[idx].label());
    }
};
