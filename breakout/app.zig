const c = @import("cimports.zig").c;
const std = @import("std");

const print = std.debug.print;

const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
var app_err: sdlGlue.ErrorStore = .{};

const GameMenu = @import("menu.zig").GameMenu;
const Game = @import("game.zig").Game;

const AppState = enum {
    Menu,
    Game,
};

pub const App = struct {
    const Self = @This();
    const state_change_fmt = "State: {any}  → {any}\n";
    const event_key_fmt = "{any}: {s}\n";
    pub const text_height: f32 = 8;
    pub const text_width: f32 = 8;
    pub const text_line_pad: f32 = 0;

    state: AppState,
    renderer: *c.SDL_Renderer,
    window: *c.SDL_Window,
    pixel_buffer: *c.SDL_Texture,
    pixel_buffer_scale: f32,
    pixel_buffer_width: f32,
    pixel_buffer_height: f32,
    window_width: i32,
    window_height: i32,
    menu: GameMenu,
    game: Game,
    handleStateEvent: *const fn (self: *Self, event: *c.SDL_Event) anyerror!c.SDL_AppResult = GameMenu.sdlEventHandler,

    pub fn init(self: *App) !void {
        const pixel_buffer_scale = 3;
        const pixel_buffer_width = 400;
        const pixel_buffer_height = 300;

        self.* = .{
            .state = AppState.Menu,
            .game = undefined,
            .menu = undefined,
            .renderer = undefined,
            .window = undefined,
            .pixel_buffer = undefined,
            .pixel_buffer_scale = pixel_buffer_scale,
            .pixel_buffer_width = pixel_buffer_width,
            .pixel_buffer_height = pixel_buffer_height,
            .window_width = pixel_buffer_width * pixel_buffer_scale,
            .window_height = pixel_buffer_height * pixel_buffer_scale,
            .handleStateEvent = GameMenu.sdlEventHandler,
        };
        print("Game.init():\n", .{});
        self.game = try Game.init(self);

        print("GameMenu.init():\n", .{});
        self.menu = GameMenu.init(self);
    }

    pub fn printStateEventKey(self: *Self, event: *c.SDL_Event) void {
        print(App.event_key_fmt, .{ self.state, c.SDL_GetKeyName(event.key.key) });
    }

    pub fn setState(self: *Self, state: AppState) void {
        const oldState = self.state;
        self.state = state;
        print(App.state_change_fmt, .{ oldState, self.state });
    }

    pub fn enterGameState(self: *Self) !void {
        self.setState(AppState.Game);
        self.handleStateEvent = Game.sdlEventHandler;
        _ = c.SDL_HideCursor();
        //self.game.state = Game.State.Running;
        try self.game.drawNoPauseCheck(self.renderer);
    }

    pub fn exitGameState(self: *Self) void {
        self.game.state = Game.State.Paused;
        self.setState(AppState.Menu);
        self.handleStateEvent = GameMenu.sdlEventHandler;
        _ = c.SDL_ShowCursor();
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
        _ = c.SDL_SetRenderTarget(self.renderer, self.pixel_buffer);
        switch (self.state) {
            AppState.Menu => {
                try self.menu.draw(self.renderer);
            },
            AppState.Game => {
                try self.game.draw(self.renderer);
            },
        }
        _ = c.SDL_SetRenderTarget(self.renderer, null);
        _ = c.SDL_RenderTexture(self.renderer, self.pixel_buffer, null, null);
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
