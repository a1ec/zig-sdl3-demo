const c = @import("cimports.zig").c;
const std = @import("std");
const gamemenu = @import("gamemenu.zig");
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;

pub const std_options: std.Options = .{ .log_level = .debug };
const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

var app_err: sdlGlue.ErrorStore = .{};

const Timekeeper = @import("timekeeper.zig").Timekeeper;
var timekeeper: Timekeeper = undefined;

const gameScreenBufferWidth = 320;
const gameScreenBufferHeight = 240;
const gameScreenScale = 3;

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
    window_w: i32 = gameScreenBufferWidth * gameScreenScale,
    window_h: i32 = gameScreenBufferHeight * gameScreenScale,

    pub fn init() Self {
        return Self{
            .state = State.Menu,
            .menu = gamemenu.GameMenu{},
        };
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

var app = App.init();

fn sdlAppIterate(appstate: ?*anyopaque) !c.SDL_AppResult {
    _ = appstate;
    while (timekeeper.consume()) {}

    try app.updateGfx();
    try errify(c.SDL_RenderPresent(app.renderer));

    timekeeper.produce(c.SDL_GetPerformanceCounter());
    return c.SDL_APP_CONTINUE;
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *c.SDL_Event) !c.SDL_AppResult {
    _ = appstate;

    switch (event.type) {
        c.SDL_EVENT_KEY_DOWN => {
            switch (event.key.key) {
                c.SDLK_S, c.SDLK_D => {
                    app.handleEvent(MenuEvent.Next);
                },
                c.SDLK_A, c.SDLK_W => {
                    app.handleEvent(MenuEvent.Prev);
                },
                c.SDLK_SPACE, c.SDLK_RETURN => {
                    app.handleEvent(MenuEvent.Select);
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
                    app.exitCurrentState();
                },
                else => {},
            }
        },
        else => {},
    }
    return c.SDL_APP_CONTINUE;
}

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !c.SDL_AppResult {
    _ = appstate;
    _ = argv;

    timekeeper = .{ .tocks_per_s = c.SDL_GetPerformanceFrequency() };

    errify(c.SDL_SetHint(c.SDL_HINT_RENDER_VSYNC, "1")) catch {};
    try errify(c.SDL_SetAppMetadata("Example", "1.0", "example.com"));
    try errify(c.SDL_Init(c.SDL_INIT_VIDEO));
    try errify(c.SDL_CreateWindowAndRenderer("examples/renderer/debug-text", app.window_w, app.window_h, 0, @ptrCast(&app.window), @ptrCast(&app.renderer)));

    try errify(c.SDL_SetRenderScale(app.renderer, gameScreenScale, gameScreenScale));
    //try errify(c.SDL_SetRenderDrawColor(app.renderer, 0x00, 0x00, 0x00, 0xff));
    try errify(c.SDL_RenderClear(app.renderer));
    return c.SDL_APP_CONTINUE;
}

fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!c.SDL_AppResult) void {
    _ = appstate;

    _ = result catch |err| if (err == error.SdlError) {
        sdl_log.err("{s}", .{c.SDL_GetError()});
    };

    c.SDL_DestroyRenderer(app.renderer);
    c.SDL_DestroyWindow(app.window);
}

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}

fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return c.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.SDL_AppResult {
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

fn sdlAppEventC(appstate: ?*anyopaque, event: ?*c.SDL_Event) callconv(.c) c.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

fn sdlAppQuitC(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}
