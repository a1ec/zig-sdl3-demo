const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");
const app_ = @import("app.zig");
const App = app_.App;
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
    playerShip: ?entity.PlayerShip,
    showGrid: bool = true,
    showMousePosition: bool = true,
    framesDrawn: u32 = 0,
    const buffer_width = 320;
    const buffer_height = 240;

    pub fn init(app: *App) !Game {
        //print("playerSHip creation:\n", .{});
        //const playerShip = try entity.PlayerShip.init(app.renderer);
        const playerShip = null;
        //
        //print("playerSHip init OK!:\n", .{});
        return Game{
            .app = app,
            .playerShip = playerShip,
        };
    }

    pub fn toggleGrid(self: *Self) void {
        self.showGrid = ~self.showGrid;
    }
    pub fn toggleMousePosition(self: *Self) void {
        self.showMousePosition = ~self.showMousePosition;
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
                    c.SDLK_M => {
                        self.toggleMousePosition();
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

        // mouse co-ordinates
        mousePos = getMousePosition(&floatx, &floaty, self.app.pixelBufferScale);
        const posX = @trunc(mousePos.x);
        const posY = @trunc(mousePos.y);
        const floatW = @as(f32, @floatFromInt(self.app.windowWidth));
        const floatH = @as(f32, @floatFromInt(self.app.windowHeight));

        // Nice blue at 0,0,0xff/2
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0xff / 2, 0xff));
        try errify(c.SDL_RenderClear(renderer));
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_NONE));

        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff * 3 / 4));
        try gfx.drawDebugTextChars(renderer, self.app, &self.textBytes);
        // with a black background, nice specular highlight effect on non-black characters
        // c.SDL_BLENDMODE_MUL on 0.75 white & 0.25 white
        //try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff * 3 / 5));
        if (self.showMousePosition) {
            try gfx.drawFmtText(renderer, posX, posY, "{d},{d}", .{ posX, posY });
        }
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 3));

        if (self.showGrid) {
            gfx.drawGrid(-1, -1, self.app.pixelBufferWidth, self.app.pixelBufferHeight, App.textWidth, App.textHeight, renderer);
        }
        //try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));
        gfx.drawCrossHairsFullScreen(posX, posY, floatW, floatH, renderer);
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
