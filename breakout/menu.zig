const std = @import("std");
const sdlGlue = @import("sdlglue.zig");
const App = @import("app.zig").App;
const print = std.debug.print;
const errify = sdlGlue.errify;
const gfx = @import("gfx.zig");

// Assumes a cimports.zig file exists for SDL bindings
const c = @import("cimports.zig").c;

/// Manages the state and navigation of a simple game menu.
pub const GameMenu = struct {
    const Self = @This();

    /// The index of the currently selected menu item.
    currentIndex: isize = 0,
    x: f32 = 0,
    y: f32 = 0,
    app: *App,
    /// Represents a single, selectable item in the menu.
    pub const Item = enum(u8) {
        NewGame,
        ResumeGame,
        Settings,
        BallIt,
        ConfirmExit,

        /// Returns the display text for a menu item.
        pub fn label(self: Item) [*c]const u8 {
            return switch (self) {
                .NewGame => "Start",
                .ResumeGame => "Resume",
                .Settings => "Settings",
                .BallIt => "Ball It!",
                .ConfirmExit => "Exit",
            };
        }
    };

    pub fn init(app: *App) GameMenu {
        return GameMenu{ .app = app };
    }

    pub fn sdlEventHandler(app: *App, event: *c.SDL_Event) !c.SDL_AppResult {
        var self = &app.menu;
        switch (event.type) {
            c.SDL_EVENT_QUIT => {
                return c.SDL_APP_SUCCESS;
            },
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_S, c.SDLK_D => {
                        self.moveSelection(1);
                    },
                    c.SDLK_A, c.SDLK_W => {
                        self.moveSelection(-1);
                    },
                    c.SDLK_SPACE, c.SDLK_RETURN => {
                        return self.handleMenuSelect();
                    },
                    else => {},
                }
                //app.printStateEventKey(event);
            },
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        _ = try app.exitCurrentState();
                        return c.SDL_APP_SUCCESS;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return c.SDL_APP_CONTINUE;
    }

    pub fn handleMenuSelect(self: *Self) !c.SDL_AppResult {
        const item = self.getSelectedItem();
        print("Select: {any}\n", .{item});
        switch (item) {
            .NewGame => {
                try self.app.enterGameState();
            },
            .ConfirmExit => {
                return c.SDL_APP_SUCCESS;
                //_ = self.exit() catch unreachable;
            },
            else => {},
        }
        return c.SDL_APP_CONTINUE;
    }

    /// A compile-time slice of all available menu items.
    pub const allItems = std.enums.values(Item);

    /// Moves the selection up or down, wrapping around the menu.
    /// - direction: -1 for up, +1 for down.
    pub fn moveSelection(self: *Self, step: isize) void {
        self.currentIndex += step;
        self.currentIndex = @mod(self.currentIndex, Self.allItems.len); // TODO self.allItems.len);
    }

    /// Returns the currently selected menu item enum.
    pub fn getSelectedItem(self: *Self) Item {
        // `allItems` is a constant on the type, not the instance.
        return Self.allItems[@intCast(self.currentIndex)];
    }

    pub fn draw(self: Self, renderer: *c.SDL_Renderer) !void {
        const textHeight: f32 = 8;
        //const textWidth: f32 = 10;
        const linePadding: f32 = 0;
        var textOpacity: u8 = 0xff;
        var bgColour: u8 = 0x00;
        var bgOpacity: u8 = 0xff;
        var menuRect: c.SDL_FRect = .{
            .x = self.x,
            .y = self.y,
            .w = 320,
            .h = textHeight,
        };

        for (Self.allItems, 0..) |item, i| {
            const isSelected = self.currentIndex == i;
            const index: f32 = @floatFromInt(i);
            textOpacity = if (isSelected) 0xff else 0xff / 16;
            bgColour = if (isSelected) 0xff else 0x00;
            bgOpacity = if (isSelected) 0xff else 0xff / 16;
            try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
            try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, bgColour, bgOpacity));
            try errify(c.SDL_RenderFillRect(renderer, &menuRect));
            try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, textOpacity));
            try gfx.drawText(renderer, self.x, self.y + index * textHeight + linePadding, "{s}", .{item.label()});
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
