const c = @import("cimports.zig").c;
const std = @import("std");

const print = std.debug.print;

const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
var app_err: sdlGlue.ErrorStore = .{};

const gamemenu = @import("menu.zig");
const GameMenu = @import("menu.zig").GameMenu;
const Game = @import("game.zig").Game;

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

const AppState = enum {
    Menu,
    Game,
};

pub const App = struct {
    const Self = @This();
    const stateChangeMsg = "State: {any}  → {any}\n";
    const eventKeyMsg = "{any}: {s}\n";

    state: AppState,
    renderer: *c.SDL_Renderer,
    window: *c.SDL_Window,
    gameScreenScale: f32,
    gameScreenBufferWidth: f32,
    gameScreenBufferHeight: f32,
    window_w: i32,
    window_h: i32,
    menu: GameMenu,
    game: Game,
    handleStateEvent: *const fn (self: *Self, event: *c.SDL_Event) anyerror!c.SDL_AppResult = App.handleMenuSdlEvent,

    pub fn init() App {
        const buffer_w = 320;
        const buffer_h = 240;
        const scale = 2;

        return App{
            .state = AppState.Menu,
            .game = Game{},
            .menu = GameMenu{},
            .renderer = undefined,
            .window = undefined,
            .gameScreenScale = scale,
            .gameScreenBufferWidth = buffer_w,
            .gameScreenBufferHeight = buffer_h,
            .window_w = buffer_w * scale,
            .window_h = buffer_h * scale,
        };
    }

    pub fn printStateEventKey(self: *Self, event: *c.SDL_Event) void {
        print(App.eventKeyMsg, .{ self.state, c.SDL_GetKeyName(event.key.key) });
    }

    pub fn handleMenuSdlEvent(self: *Self, event: *c.SDL_Event) !c.SDL_AppResult {
        switch (event.type) {
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_S, c.SDLK_D => {
                        try self.handleEvent(MenuEvent.Next);
                    },
                    c.SDLK_A, c.SDLK_W => {
                        try self.handleEvent(MenuEvent.Prev);
                    },
                    c.SDLK_SPACE, c.SDLK_RETURN => {
                        try self.handleEvent(MenuEvent.Select);
                    },
                    else => {},
                }
                self.printStateEventKey(event);
            },
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        _ = try self.exitCurrentState();
                        return c.SDL_APP_SUCCESS;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return c.SDL_APP_CONTINUE;
    }

    pub fn handleGameSdlEvent(self: *Self, event: *c.SDL_Event) !c.SDL_AppResult {
        switch (event.type) {
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        return self.exitCurrentState();
                    },
                    else => {},
                }
            },
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_P => {
                        self.game.state = Game.State.Paused;
                    },
                    c.SDLK_R => {
                        self.game.state = Game.State.Running;
                    },
                    else => {},
                }
            },
            else => {},
        }
        self.printStateEventKey(event);
        return c.SDL_APP_CONTINUE;
    }

    pub fn exitCurrentState(self: *Self) !c.SDL_AppResult {
        const oldState = self.state;
        switch (self.state) {
            AppState.Game => {
                self.exitGameState();
            },
            AppState.Menu => {
                print(App.stateChangeMsg, .{ oldState, self.state });
                return c.SDL_APP_SUCCESS;
            },
        }
        print(App.stateChangeMsg, .{ oldState, self.state });
        return c.SDL_APP_CONTINUE;
    }

    pub fn handleMenuSelect(self: *Self, item: GameMenu.Item) !c.SDL_AppResult {
        switch (item) {
            .NewGame => {
                self.enterGameState();
            },
            .ConfirmExit => {
                return c.SDL_APP_SUCCESS;
                //_ = self.exit() catch unreachable;
            },
            else => {},
        }
        return c.SDL_APP_CONTINUE;
    }

    fn enterGameState(self: *Self) void {
        self.state = AppState.Game;
        self.handleStateEvent = App.handleGameSdlEvent;
    }

    fn exitGameState(self: *Self) void {
        self.game.state = Game.State.Paused;
        self.state = AppState.Menu;
        self.handleStateEvent = App.handleMenuSdlEvent;
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
        }
        try errify(c.SDL_RenderPresent(self.renderer));
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
                    _ = try self.handleMenuSelect(self.menu.getSelectedItem());
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
