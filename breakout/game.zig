const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");

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

    //    pub fn handleSdlEvent(self: *Self, app: *App, event: *c.SDL_Event) !c.SDL_AppResult {
    //       switch (event.type) {
    //          c.SDL_EVENT_KEY_DOWN => {
    //                switch (event.key.key) {
    //                    c.SDLK_ESCAPE => {
    //                        return app.exitCurrentState();
    //                    },
    //                    c.SDLK_P => {
    //                        self.state = State.Paused;
    //                    },
    //                    c.SDLK_R => {
    //                        self.state = State.Running;
    //                    },
    //                    else => {},
    //                }
    //            },
    //            else => {},
    //        }
    //        App.printStateEventKey(event);
    //        return c.SDL_APP_CONTINUE;
    //    }

    pub fn draw(self: *Self, renderer: *c.SDL_Renderer) !void {
        if (self.state == State.Paused) {
            return;
        }

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

        self.framesDrawn += 1;
    }
};
