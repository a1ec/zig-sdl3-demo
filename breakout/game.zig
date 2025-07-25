const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");
const app_ = @import("app.zig");
const App = app_.App;
const print = std.debug.print;
const gfx = @import("gfx.zig");
const entity = @import("entity.zig");
const Point = @import("Point.zig");
const Curve = @import("Curve.zig");

pub const Game = struct {
    const Self = @This();
    pub const State = enum {
        Paused,
        Running,
    };

    text_bytes: [256]u8 = entity.generateCharacterBytes(),
    state: State = State.Running,
    app: *App = undefined,
    player_ship: ?entity.PlayerShip,
    is_grid_shown: bool = true,
    is_mouse_pos_shown: bool = true,
    frames_drawn: u32 = 0,
    const buffer_width = 320;
    const buffer_height = 240;

    pub fn init(app: *App) !Game {
        //print("playerSHip creation:\n", .{});
        //const player_ship = try entity.PlayerShip.init(app.renderer);
        const player_ship = null;
        //
        //print("playerSHip init OK!:\n", .{});
        return Game{
            .app = app,
            .player_ship = player_ship,
        };
    }

    pub fn toggleGrid(self: *Self) void {
        self.is_grid_shown = ~self.is_grid_shown;
    }
    pub fn toggleMousePosition(self: *Self) void {
        self.is_mouse_pos_shown = ~self.is_mouse_pos_shown;
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

    pub fn drawPlayerShip(self: *Self, renderer: *c.SDL_Renderer) !void {
        const destRect = c.SDL_FRect{
            .x = self.player_ship.x - (16 / 2.0),
            .y = self.player_ship.y - (24 / 2.0),
            .w = 16,
            .h = 24,
        };
        try errify(c.SDL_RenderTexture(
            renderer,
            self.player_ship.texture,
            null, // srcrect: null to use the whole texture
            &destRect,
        ));
    }

    var old_parabola_points = init: {
        var initial_value: [320]c.SDL_FPoint = undefined;
        for (&initial_value, 0..) |*pt, i| {
            const index = @as(f32, @floatFromInt(i));
            const x = index;
            const y = -(index * index) / 420 + 240;
            pt.* = c.SDL_FPoint{
                .x = x,
                .y = y,
            };
        }
        break :init initial_value;
    };

    pub fn drawNoPauseCheck(self: *Self, renderer: *c.SDL_Renderer) !void {
        var floatx: f32 = 0;
        var floaty: f32 = 0;
        var mousePos: Point = .{ .x = 0, .y = 0 };

        //const graph_points = generate240Points();
        // mouse co-ordinates
        mousePos = getMousePosition(&floatx, &floaty, self.app.pixel_buffer_scale);
        const posX = @trunc(mousePos.x);
        const posY = @trunc(mousePos.y);
        const floatW = @as(f32, @floatFromInt(self.app.window_width));
        const floatH = @as(f32, @floatFromInt(self.app.window_height));

        //var graph_points = Curve.generatePoints(320, Curve.sine(x: f32, a: f32, b: f32, c_: f32))

        // Nice blue at 0,0,0xff/2
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0xff / 2, 0xff));
        try errify(c.SDL_RenderClear(renderer));
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_NONE));

        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff * 3 / 4));
        // try gfx.drawDebugTextChars(renderer, self.app, &self.text_bytes);

        // with a black background, nice specular highlight effect on non-black characters
        // c.SDL_BLENDMODE_MUL on 0.75 white & 0.25 white
        //try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff * 3 / 5));
        if (self.is_mouse_pos_shown) {
            try gfx.drawFmtText(renderer, posX, posY, "{d},{d}", .{ posX, posY });
        }
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 3));

        // draw a parabolic curve
        const my_parabola_config = Curve.ParabolaContext{
            .a = posY / 500,
            .b = posX / 30,
            .c_ = 0,
        };

        var graph_points = Curve.generatePointsWithContext(320, &my_parabola_config, // Pass a pointer to the context struct
            Curve.ParabolaContext.calc // Pass the function
        );

        const my_sine_config = Curve.SineWaveContext{
            .amplitude = 25.0 * posY / 50,
            .frequency = posX * 0.2 / 80,
            .y_offset = 120.0,
        };

        graph_points = Curve.generatePointsWithContext(320, &my_sine_config, // Pass a pointer to the context struct
            Curve.SineWaveContext.calc // Pass the function
        );

        for (0..(graph_points.len - 1)) |i| {
            const p1 = graph_points[i];
            const p2 = graph_points[i + 1];
            _ = c.SDL_RenderLine(renderer, p1.x, p1.y, p2.x, p2.y);
        }

        //_ = c.SDL_RenderPoints(renderer, &graph_points, graph_points.len);
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        if (self.is_grid_shown) {
            gfx.drawGrid(renderer, -1, -1, self.app.pixel_buffer_width, self.app.pixel_buffer_height, App.text_width, App.text_height);
        }
        //try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));
        gfx.drawCrossHairsFullScreen(renderer, posX, posY, floatW, floatH);
    }

    pub fn getMousePosition(x: *f32, y: *f32, scale: f32) Point {
        _ = c.SDL_GetMouseState(x, y);
        return .{ .x = x.* / scale, .y = y.* / scale };
    }

    pub fn draw(self: *Self, renderer: *c.SDL_Renderer) !void {
        _ = try self.drawNoPauseCheck(renderer);
        if (self.state == State.Running) {
            self.frames_drawn += 1;
        }
    }
};
