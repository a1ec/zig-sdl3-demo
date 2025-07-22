const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");
const App = @import("app.zig").App;
const print = std.debug.print;

fn generateCharacterBytes() [256]u8 {
    var buffer: [256]u8 = undefined;
    for (0..255) |i| {
        buffer[i] = @intCast(i + 1);
    }
    buffer[255] = 0;
    return buffer;
}

pub const Game = struct {
    const Self = @This();
    pub const State = enum {
        Paused,
        Running,
    };

    framesDrawn: u32 = 0,
    gameStr: [100]u8 = undefined,
    textBytes: [256]u8 = generateCharacterBytes(),
    state: State = State.Running,
    app: *App = undefined,

    pub fn init(app: *App) Game {
        return Game{ .app = app };
    }

    pub fn sdlEventHandler(app: *App, event: *c.SDL_Event) !c.SDL_AppResult {
        var self = &app.game;
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
        //app.printStateEventKey(event);
        return c.SDL_APP_CONTINUE;
    }

    pub fn drawGrid(x: f32, y: f32, w: f32, h: f32, divX: f32, divY: f32, renderer: *c.SDL_Renderer) void {
        var cursorX: f32 = 0;
        var cursorY: f32 = 0;
        //draw horizontals
        while (cursorY <= h) {
            _ = c.SDL_RenderLine(renderer, cursorX + x, cursorY + y, w, cursorY + y);
            cursorY += divY;
        }
        cursorY = 0;
        while (cursorX <= w) {
            _ = c.SDL_RenderLine(renderer, cursorX + x, cursorY + y, cursorX + x, h);
            cursorX += divX;
        }
    }

    const Point = struct { x: f32 = 0, y: f32 = 0 };

    pub fn drawNoPauseCheck(self: *Self, renderer: *c.SDL_Renderer) !void {
        var floatx: f32 = 0;
        var floaty: f32 = 0;
        var mousePos: Point = .{ .x = 0, .y = 0 };
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x88, 0xaa));
        try errify(c.SDL_RenderClear(renderer));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff));
        // Use subslice to ensure buffer has at least 1 byte of free space for the null.
        const buffer = self.gameStr[0 .. self.gameStr.len - 1];
        var message_slice = try std.fmt.bufPrint(buffer, "{any} frames: {d}", .{ self.state, self.framesDrawn });

        // Manually add the null terminator.
        self.gameStr[message_slice.len] = 0;
        // The C function will read up to the null byte we just wrote.
        try errify(c.SDL_RenderDebugText(renderer, 0, 0, &self.gameStr[0]));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff * 3 / 5));
        try errify(c.SDL_RenderDebugText(renderer, 0, 16, &self.textBytes[32]));
        try errify(c.SDL_RenderDebugText(renderer, 0, 24, &self.textBytes[64]));
        message_slice = try std.fmt.bufPrint(buffer, "{any}\x00", .{
            @TypeOf(&self.textBytes[64]),
        });
        mousePos = getMousePosition(&floatx, &floaty, self.app.gameScreenScale);
        message_slice = try std.fmt.bufPrint(buffer, "{d},{d}\x00", .{ @as(u32, @intFromFloat(mousePos.x)), @as(u32, @intFromFloat(mousePos.y)) });
        try errify(c.SDL_RenderDebugText(renderer, 0, 48, &message_slice[0]));

        // with a black background, results in a specular highlight effect
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));

        // cross hair
        // horizontal line
        _ = c.SDL_RenderLine(renderer, 0, mousePos.y, @as(f32, @floatFromInt(self.app.window_w)), mousePos.y);
        // vertical line
        _ = c.SDL_RenderLine(renderer, mousePos.x, 0, mousePos.x, @as(f32, @floatFromInt(self.app.window_h)));
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 4));
        drawGrid(-1, -1, 320, 240, 320 / 40, 240 / 30, renderer);
    }

    pub fn getMousePosition(x: *f32, y: *f32, scale: f32) Point {
        _ = c.SDL_GetMouseState(x, y);
        return .{ .x = x.* / scale, .y = y.* / scale };
    }

    pub fn draw(self: *Self, renderer: *c.SDL_Renderer) !void {
        _ = try self.drawNoPauseCheck(renderer);
        if (self.state == State.Running) {
            self.framesDrawn += 1;
        }
    }

    //pub fn drawText(
};
