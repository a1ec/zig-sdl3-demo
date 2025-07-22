const c = @import("cimports.zig").c;
const std = @import("std");

const print = std.debug.print;

const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
var app_err: sdlGlue.ErrorStore = .{};

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
    handleStateEvent: *const fn (self: *Self, event: *c.SDL_Event) anyerror!c.SDL_AppResult = GameMenu.sdlEventHandler,

    pub fn init(self: *App) void {
        const buffer_w = 320;
        const buffer_h = 240;
        const scale = 4;

        self.* = .{
            .state = AppState.Menu,
            .game = undefined,
            .menu = undefined,
            .renderer = undefined,
            .window = undefined,
            .gameScreenScale = scale,
            .gameScreenBufferWidth = buffer_w,
            .gameScreenBufferHeight = buffer_h,
            .window_w = buffer_w * @as(f32, @floatFromInt(scale)),
            .window_h = buffer_h * @as(f32, @floatFromInt(scale)),
            .handleStateEvent = GameMenu.sdlEventHandler,
        };
        self.game = Game.init(self);
        self.menu = GameMenu.init(self);
    }

    pub fn printStateEventKey(self: *Self, event: *c.SDL_Event) void {
        print(App.eventKeyMsg, .{ self.state, c.SDL_GetKeyName(event.key.key) });
    }

    pub fn setState(self: *Self, state: AppState) void {
        const oldState = self.state;
        self.state = state;
        print(App.stateChangeMsg, .{ oldState, self.state });
    }

    pub fn enterGameState(self: *Self) !void {
        self.setState(AppState.Game);
        self.handleStateEvent = Game.sdlEventHandler;
        //self.game.state = Game.State.Running;
        try self.game.drawNoPauseCheck(self.renderer);
    }

    pub fn exitGameState(self: *Self) void {
        self.game.state = Game.State.Paused;
        self.setState(AppState.Menu);
        self.handleStateEvent = GameMenu.sdlEventHandler;
    }

    pub fn exitCurrentState(self: *Self) !c.SDL_AppResult {
        switch (self.state) {
            AppState.Game => {
                self.exitGameState();
            },
            AppState.Menu => {
                return c.SDL_APP_SUCCESS;
            },
        }
        return c.SDL_APP_CONTINUE;
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
};

const sdlMainC = sdlGlue.sdlMainC;

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}
