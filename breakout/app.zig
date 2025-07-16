const c = @import("cimports.zig").c;
const std = @import("std");

const print = std.debug.print;

const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
var app_err: sdlGlue.ErrorStore = .{};

const gamemenu = @import("gamemenu.zig");

const textHeight: f32 = 10;
const textWidth: f32 = 10;
const linePad: f32 = 2;

pub const AppEvent = enum {
    ExitCurrentState,
};

pub const MenuEvent = enum {
    Next,
    Prev,
    Select,
};

const Game = struct {
    const Self = @This();
    const State = enum {
        Paused,
        Running,
    };

    pub fn draw(self: Self, renderer: *c.SDL_Renderer) !void {
        _ = self;
        _ = renderer;
        std.debug.print("g", .{});
    }
};

const AppState = enum {
    Menu,
    Game,
    ConfirmExit,
};

pub const App = struct {
    const Self = @This();
    state: AppState,
    renderer: *c.SDL_Renderer,
    window: *c.SDL_Window,
    gameScreenScale: f32,
    gameScreenBufferWidth: f32,
    gameScreenBufferHeight: f32,
    window_w: i32,
    window_h: i32,
    menu: gamemenu.GameMenu,
    game: Game,

    pub fn init() App {
        const scale = 3;
        const buffer_w = 320;
        const buffer_h = 240;

        return App{
            .state = AppState.Menu,
            .game = Game{},
            .menu = gamemenu.GameMenu{},
            .renderer = undefined,
            .window = undefined,
            .gameScreenScale = scale,
            .gameScreenBufferWidth = buffer_w,
            .gameScreenBufferHeight = buffer_h,
            .window_w = buffer_w * scale,
            .window_h = buffer_h * scale,
        };
    }

    pub fn handleSdlEvent(self: *Self, event: *c.SDL_Event) !c.SDL_AppResult {
        switch (event.type) {
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_S, c.SDLK_D => {
                        self.handleEvent(MenuEvent.Next) catch unreachable;
                    },
                    c.SDLK_A, c.SDLK_W => {
                        self.handleEvent(MenuEvent.Prev) catch unreachable;
                    },
                    c.SDLK_SPACE, c.SDLK_RETURN => {
                        self.handleEvent(MenuEvent.Select) catch unreachable;
                    },
                    else => {},
                }
                const keyboard_event = event.key;
                print("Key Down: {s}\n", .{
                    c.SDL_GetKeyName(keyboard_event.key),
                });
            },
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        //self.exitCurrentState();
                        return c.SDL_APP_SUCCESS;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return c.SDL_APP_CONTINUE;
    }

    pub fn exitCurrentState(self: *Self) void {
        switch (self.state) {
            AppState.Game => {
                self.state = AppState.Menu;
            },
            AppState.Menu => {
                self.state = AppState.ConfirmExit;
            },
            AppState.ConfirmExit => {
                self.state = AppState.Menu;
            },
        }
    }

    pub fn handleMenuSelect(self: *Self, item: gamemenu.GameMenu.Item) !void {
        switch (item) {
            .NewGame => {
                self.enterGameState();
            },
            .ConfirmExit => {
                std.debug.print("Exiting.... ", .{}); // handle enter
                _ = self.exit() catch unreachable;
            },
            else => {},
        }
    }

    fn enterGameState(self: *Self) void {
        std.debug.print("Entering.... ", .{}); // handle enter
        self.state = AppState.Game;
    }

    fn exit(self: *Self) !c.SDL_AppResult {
        _ = self;
        return c.SDL_APP_SUCCESS;
    }

    pub fn updateGfx(self: *Self) !void {
        switch (self.state) {
            AppState.Menu => {
                try self.menu.draw(self.renderer);
            },
            AppState.Game => {
                try self.game.draw(self.renderer);
            },
            else => {},
        }
    }

    pub fn handleEvent(self: *Self, event: MenuEvent) !void {
        switch (self.state) {
            .Menu => switch (event) {
                .Next => {
                    self.menu.moveSelection(1);
                },
                .Prev => {
                    self.menu.moveSelection(-1);
                },
                .Select => {
                    try self.handleMenuSelect(self.menu.getSelectedItem());
                },
            },
            else => {},
        }
    }
};

const sdlMainC = sdlGlue.sdlMainC;

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}
