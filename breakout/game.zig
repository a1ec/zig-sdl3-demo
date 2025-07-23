const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");
const App = @import("app.zig").App;
const print = std.debug.print;
const gfx = @import("gfx.zig");

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

    const Point = struct { x: f32 = 0, y: f32 = 0 };

    //pub fn drawText(comptime fmt: []const u8, args: anytype, renderer: *c.SDL_Renderer) void {
    // drawText("{}", .{myStr,}, renderer);
    //  const buffer = self.[0 .. self.gameStr.len - 1];
    //var message_slice = try std.fmt.bufPrint(buffer, "{any} frames: {d}", .{ self.state, self.framesDrawn });
    //}

    pub fn drawNoPauseCheck(self: *Self, renderer: *c.SDL_Renderer) !void {
        var floatx: f32 = 0;
        var floaty: f32 = 0;
        var mousePos: Point = .{ .x = 0, .y = 0 };

        var gameStr: [100]u8 = undefined;

        try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0xaa, 0xff));
        try errify(c.SDL_RenderClear(renderer));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff));

        // Use subslice to ensure buffer has at least 1 byte of free space for the null.
        const buffer = gameStr[0 .. gameStr.len - 1];
        var message_slice = try std.fmt.bufPrint(buffer, "{any} frames: {d}", .{ self.state, self.framesDrawn });
        // Manually add the null terminator.
        gameStr[message_slice.len] = 0;
        // The C function will read up to the null byte we just wrote.
        try errify(c.SDL_RenderDebugText(renderer, 0, 0, &gameStr[0]));

        // draw all debug characters
        var line: u8 = 1;
        const textHeight = 8;
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff * 3 / 5));
        while (line < 8) {
            try errify(c.SDL_RenderDebugText(renderer, 0, @as(f32, @floatFromInt(line * textHeight)), &self.textBytes[40 * (line - 1)])); // .. 40 * line]));
            line += 1;
        }
        // mouse co-ordinates
        mousePos = getMousePosition(&floatx, &floaty, self.app.gameScreenScale);
        const intX = @trunc(mousePos.x);
        const intY = @trunc(mousePos.y);
        const floatW = @as(f32, @floatFromInt(self.app.window_w));
        const floatH = @as(f32, @floatFromInt(self.app.window_h));
        message_slice = try std.fmt.bufPrint(buffer, "{d},{d}\x00", .{ intX, intY });
        try errify(c.SDL_RenderDebugText(renderer, 0, @as(f32, @floatFromInt(line * textHeight)), &message_slice[0]));

        // with a black background, nice specular highlight effect on non-black
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));

        // cross hairs, horizontal line
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff * 3 / 5));
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 4));
        gfx.drawGrid(-1, -1, 320, 240, 320 / 40, 240 / 30, renderer);
        gfx.drawCrossHairsFullScreen(intX, intY, floatW, floatH, renderer);
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
};
