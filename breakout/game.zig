const c = @import("cimports.zig").c;
const sdlGlue = @import("sdlglue.zig");
const errify = sdlGlue.errify;
const std = @import("std");
const app_ = @import("app.zig");
const App = app_.App;
const print = std.debug.print;
const Gfx = @import("Gfx.zig");
const entity = @import("entity.zig");
const Point = @import("Point.zig");
const Curve = @import("Curve.zig");
const Input = @import("Input.zig");

pub const Game = struct {
    const Self = @This();

    pub const State = enum {
        Paused,
        Running,
    };

    state: State = State.Running,
    app: *App = undefined,
    is_grid_shown: bool = true,
    is_mouse_pos_shown: bool = true,
    frames_drawn: u32 = 0,

    pub fn init(app: *App) !Game {
        return Game{ .app = app };
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

    pub fn drawNoPauseCheck(self: *Self, renderer: *c.SDL_Renderer) !void {
        var floatx: f32 = 0;
        var floaty: f32 = 0;
        var mousePos: Point = .{ .x = 0, .y = 0 };

        //const graph_points = generate240Points();
        // mouse co-ordinates
        mousePos = Input.getMousePosition(&floatx, &floaty, self.app.pixel_buffer_scale);
        const posX = @trunc(mousePos.x);
        const posY = @trunc(mousePos.y);
        const floatW = @as(f32, @floatFromInt(self.app.window_width));
        const floatH = @as(f32, @floatFromInt(self.app.window_height));

        // Nice blue at 0,0,0xff/2
        try errify(c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0xff / 2, 0xff));
        try errify(c.SDL_RenderClear(renderer));
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_NONE));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff * 3 / 4));

        // with a black background, nice specular highlight effect on non-black characters
        // c.SDL_BLENDMODE_MUL on 0.75 white & 0.25 white
        //try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_MUL));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 3));
        if (self.is_mouse_pos_shown) {
            try Gfx.drawFmtText(renderer, posX, posY, "{d},{d}", .{ posX, posY });
        }
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff * 1 / 2, 0xff * 1 / 2, 0xff, 0xff));

        // draw a parabolic curve
        const my_parabola_config = Curve.ParabolaContext{
            .a = posY / 500,
            .b = posX / 30,
            .c_ = 0,
        };

        var graph_points = Curve.generatePointsWithContext(400, &my_parabola_config, // Pass a pointer to the context struct
            Curve.ParabolaContext.calc // Pass the function
        );

        Gfx.drawCurve(renderer, &graph_points);

        const my_sine_config = Curve.SineWaveContext{
            .amplitude = 25.0 * posY / 50,
            .frequency = posX * 0.2 / 80,
            .y_offset = 120.0,
        };

        graph_points = Curve.generatePointsWithContext(400, &my_sine_config, // Pass a pointer to the context struct
            //graph_points = Curve.generatePointsWithContext(self.app.pixel_buffer_width, &my_sine_config, // Pass a pointer to the context struct
            Curve.SineWaveContext.calc // Pass the function
        );

        Gfx.drawCurve(renderer, &graph_points);

        //_ = c.SDL_RenderPoints(renderer, &graph_points, graph_points.len);
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 8));
        if (self.is_grid_shown) {
            Gfx.drawGrid(renderer, -1, -1, self.app.pixel_buffer_width, self.app.pixel_buffer_height, App.text_width, App.text_height);
        }

        Gfx.drawCrossHairsFullScreen(renderer, posX, posY, floatW, floatH);
    }

    pub fn draw(self: *Self, renderer: *c.SDL_Renderer) !void {
        _ = try self.drawNoPauseCheck(renderer);
        if (self.state == State.Running) {
            self.frames_drawn += 1;
        }
    }
};
