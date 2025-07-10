const c = @import("cimports.zig").c;
const std = @import("std");

const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
var app_err: sdlGlue.ErrorStore = .{};

const gamemenu = @import("gamemenu.zig");

const gameScreenBufferWidth = 320;
const gameScreenBufferHeight = 240;

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

const App = struct {
    const Self = @This();
    const State = enum {
        Menu,
        Game,
        ConfirmExit,
    };

    state: State,
    game: Game = Game{},
    menu: gamemenu.GameMenu = undefined,
    renderer: *c.SDL_Renderer = undefined,
    window: *c.SDL_Window = undefined,
    gameScreenScale: u32 = 3,
    window_w: i32 = gameScreenBufferWidth * gameScreenScale,
    window_h: i32 = gameScreenBufferHeight * gameScreenScale,

    pub fn init() Self {
        return Self{
            .state = State.Menu,
            .menu = gamemenu.GameMenu{},
        };
    }

    pub fn handleSdlEvent(self: *Self, event: *c.SDL_Event) void {
        switch (event.type) {
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_S, c.SDLK_D => {
                        self.handleEvent(MenuEvent.Next);
                    },
                    c.SDLK_A, c.SDLK_W => {
                        self.handleEvent(MenuEvent.Prev);
                    },
                    c.SDLK_SPACE, c.SDLK_RETURN => {
                        self.handleEvent(MenuEvent.Select);
                    },
                    else => {},
                }
                const keyboard_event = event.key;
                std.debug.print("Key Down: {s}\n", .{
                    c.SDL_GetKeyName(keyboard_event.key),
                });
            },
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        self.exitCurrentState();
                    },
                    else => {},
                }
            },
            else => {},
        }
    }

    pub fn exitCurrentState(self: *Self) void {
        switch (self.state) {
            State.Game => {
                self.state = State.Menu;
            },
            State.Menu => {
                self.state = State.ConfirmExit;
            },
            State.ConfirmExit => {
                self.state = State.Menu;
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
                try errify(self.exit());
            },
            else => {},
        }
    }

    fn enterGameState(self: *Self) void {
        std.debug.print("Entering.... ", .{}); // handle enter
        self.state = State.Game;
    }

    fn exit(self: *Self) !c.SDL_AppResult {
        _ = self;
        return c.SDL_APP_SUCCESS;
    }

    pub fn updateGfx(self: *Self) !void {
        switch (self.state) {
            State.Menu => {
                try self.menu.draw(self.renderer);
            },
            State.Game => {
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

pub var app = App.init();

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}
