const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");
const App = @import("app.zig").App;
const print = std.debug.print;
const gfx = @import("gfx.zig");
const entity = @import("entity.zig");

pub const Game = struct {
    const Self = @This();
    pub const State = enum {
        Paused,
        Running,
    };

    textBytes: [256]u8 = entity.generateCharacterBytes(),
    state: State = State.Running,
    app: *App = undefined,
    playerShip: entity.PlayerShip,
    showGrid: bool = true,
    framesDrawn: u32 = 0,
    const buffer_width = 320;
    const buffer_height = 240;

    pub fn init(app: *App) !Game {
        const playerShip = try entity.PlayerShip.init(app.renderer);
        return Game{
            .app = app,
            .playerShip = playerShip,
        };
    }

    pub fn toggleGrid(self: *Self) void {
        self.showGrid = ~self.showGrid;
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
                    c.SDLK_G => {
                        self.toggleGrid();
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

    pub fn drawPlayerShip(self: *Self, renderer: *c.SDL_Renderer) !void {
        const destRect = c.SDL_FRect{
            .x = self.playerShip.x - (16 / 2.0),
            .y = self.playerShip.y - (24 / 2.0),
            .w = 16,
            .h = 24,
        };
        try errify(c.SDL_RenderTexture(
            renderer,
            self.playerShip.texture,
            null, // srcrect: null to use the whole texture
            &destRect,
        ));
    }

    pub fn drawNoPauseCheck(self: *Self, renderer: *c.SDL_Renderer) !void {
        var floatx: f32 = 0;
        var floaty: f32 = 0;
        var mousePos: Point = .{ .x = 0, .y = 0 };

        var gameStr: [100]u8 = undefined;
        //const playerShipTexture = entity.bakePlayerShipTexture(renderer);

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
        // with a black background, nice specular highlight effect on non-black
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));

        if (self.showGrid) {
            gfx.drawGrid(-1, -1, 320, 240, 320 / 40, 240 / 30, renderer);
        }
        message_slice = try std.fmt.bufPrint(buffer, "{d},{d}\x00", .{ intX, intY });
        // cross hairs, horizontal line
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff * 3 / 5));
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_RenderDebugText(renderer, 0, @as(f32, @floatFromInt(line * textHeight)), &message_slice[0]));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 4));

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
