const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");
const App = @import("app.zig").App;
const print = std.debug.print;

pub const Game = struct {
    const Self = @This();
    pub const State = enum {
        Paused,
        Running,
    };

    framesDrawn: u32 = 0,
    gameStr: [100]u8 = undefined,
    state: State = State.Running,
    app: *App = undefined,

    pub fn init(app: *App) Game {
        return Game{ .app = app };
    }

    pub fn sdlEventHandler(app: *App, event: *c.SDL_Event) !c.SDL_AppResult {
        var self = app.game;
        switch (event.type) {
            c.SDL_EVENT_KEY_UP => {
                switch (event.key.key) {
                    c.SDLK_ESCAPE => {
                        return app.exitCurrentState();
                    },
                    else => {},
                }
            },
            c.SDL_EVENT_KEY_DOWN => {
                switch (event.key.key) {
                    c.SDLK_P => {
                        self.state = Game.State.Paused;
                    },
                    c.SDLK_R => {
                        self.state = Game.State.Running;
                    },
                    else => {},
                }
            },
            else => {},
        }
        app.printStateEventKey(event);
        return c.SDL_APP_CONTINUE;
    }

    pub fn drawNoPauseCheck(self: *Self, renderer: *c.SDL_Renderer) !void {
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xaa));
        try errify(c.SDL_RenderClear(renderer));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x12, 0x34, 0x56, 0xaa));
        _ = try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff));
        // Use subslice to ensure buffer has at least 1 byte of free space for the null.
        const buffer = self.gameStr[0 .. self.gameStr.len - 1];
        const message_slice = try std.fmt.bufPrint(buffer, "{any} frames: {d}", .{ self.state, self.framesDrawn });

        // Manually add the null terminator.
        self.gameStr[message_slice.len] = 0;
        // The C function will read up to the null byte we just wrote.
        _ = try errify(c.SDL_RenderDebugText(renderer, 0, 0, &self.gameStr[0]));
    }

    pub fn draw(self: *Self, renderer: *c.SDL_Renderer) !void {
        _ = try self.drawNoPauseCheck(renderer);
        if (self.state == State.Running) {
            self.framesDrawn += 1;
        }
    }
};
