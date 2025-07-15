const std = @import("std");
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;

// Assumes a cimports.zig file exists for SDL bindings
const c = @import("cimports.zig").c;

/// Manages the state and navigation of a simple game menu.
pub const GameMenu = struct {
    const Self = @This();

    /// The index of the currently selected menu item.
    currentIndex: isize = 0,
    x: f32 = 1,
    y: f32 = 1,
    /// Represents a single, selectable item in the menu.
    pub const Item = enum(u8) {
        NewGame,
        ResumeGame,
        ConfirmExit,

        /// Returns the display text for a menu item.
        pub fn label(self: Item) [*c]const u8 {
            return switch (self) {
                .NewGame => "New Game",
                .ResumeGame => "Resume Game",
                .ConfirmExit => "Exit",
            };
        }
    };

    /// A compile-time slice of all available menu items.
    pub const allItems = std.enums.values(Item);

    /// Moves the selection up or down, wrapping around the menu.
    /// - direction: -1 for up, +1 for down.
    pub fn moveSelection(self: *Self, step: isize) void {
        self.currentIndex += step;
        self.currentIndex = @mod(self.currentIndex, 3); // TODO self.allItems.len);
    }

    /// Returns the currently selected menu item enum.
    pub fn getSelectedItem(self: Self) Item {
        // `allItems` is a constant on the type, not the instance.
        return Self.allItems[@intCast(self.currentIndex)];
    }

    pub fn draw(self: Self, renderer: *c.SDL_Renderer) !void {
        const textHeight: f32 = 8;
        //const textWidth: f32 = 10;
        const linePadding: f32 = 0;
        var fillColour: u8 = 0x00;
        var menuRect: c.SDL_FRect = .{
            .x = self.x,
            .y = self.y,
            .w = 320,
            .h = textHeight,
        };

        for (Self.allItems, 0..) |item, i| {
            const isSelected = if (self.currentIndex == i) true else false;
            const index: f32 = @floatFromInt(i);
            fillColour = if (isSelected) 0xaa else 0x00;
            _ = try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, fillColour, 0xaa));
            _ = try errify(c.SDL_RenderFillRect(renderer, &menuRect));
            _ = try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x22, 0xff));
            _ = try errify(c.SDL_RenderDebugText(renderer, self.x, self.y + index * textHeight + linePadding, item.label()));
            menuRect.y += textHeight + linePadding;
        }
        //return c.SDL_APP_CONTINUE;
    }
};

// It's good practice to include a test block to verify the logic.
test "GameMenu navigation" {
    //const ally = std.testing.allocator;
    const eql = std.testing.expectEqual;

    var menu = GameMenu{};

    // Initial state
    try eql(0, menu.currentIndex);
    try eql(GameMenu.Item.NewGame, menu.getSelectedItem());
    try eql("New Game", menu.getSelectedItem().label());

    // Move down
    menu.moveSelection(1);
    try eql(1, menu.currentIndex);
    try eql(GameMenu.Item.ResumeGame, menu.getSelectedItem());
    menu.draw();

    // Move down again to wrap to the start
    menu.moveSelection(1);
    menu.moveSelection(1);
    try eql(0, menu.currentIndex);
    try eql(GameMenu.Item.NewGame, menu.getSelectedItem());
    menu.draw();
    // Move up to wrap to the end
    menu.moveSelection(-1);
    try eql(2, menu.currentIndex);
    try eql(GameMenu.Item.Exit, menu.getSelectedItem());
    try eql("Exit", menu.getSelectedItem().label());
}
