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

    const memory_buffer_size = 1 * 1024 * 1024;

    pub const State = enum { Paused, Running };

    state: State = .Running,
    app: *App = undefined,
    is_grid_shown: bool = true,
    is_mouse_pos_shown: bool = true,
    frames_drawn: u32 = 0,
    mouse_pos: Point,
    buffer: [memory_buffer_size]u8 = undefined,
    fba: std.heap.FixedBufferAllocator = undefined,
    allocator: std.mem.Allocator,

    pub fn init(self: *Self, app: *App) !void {
        self.state = .Running;
        self.app = app;
        self.is_grid_shown = true;
        self.is_mouse_pos_shown = true;
        self.frames_drawn = 0;
        self.fba = std.heap.FixedBufferAllocator.init(&self.buffer);
        self.allocator = self.fba.allocator();
        self.mouse_pos = .{ .x = 0, .y = 0 };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
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

    pub fn drawCurves(self: *Self) !void {
        const pixel_buffer_width_usize = @as(usize, @intFromFloat(self.app.pixel_buffer_width));
        // draw a parabolic curve
        const my_parabola_config = Curve.ParabolaContext{
            .a = self.mouse_pos.y / 500,
            .b = self.mouse_pos.x / 30,
            .c_ = 0,
        };

        var graph_points = Curve.generatePointsArrayFromContext(400, &my_parabola_config, // Pass a pointer to the context struct
            Curve.ParabolaContext.calc // Pass the function
        );

        Gfx.drawCurve(self.app.renderer, &graph_points);

        const my_sine_config = Curve.SineWaveContext{
            .amplitude = 25.0 * self.mouse_pos.y / 50,
            .frequency = self.mouse_pos.x * 0.2 / 80,
            .y_offset = 120.0,
        };

        const graph_points_slice = try Curve.generatePointsSliceFromContext(self.allocator, pixel_buffer_width_usize, &my_sine_config, // Pass a pointer to the context struct
            //graph_points = Curve.generatePointsArrayFromContext(self.app.pixel_buffer_width, &my_sine_config, // Pass a pointer to the context struct
            Curve.SineWaveContext.calc // Pass the function
        );
        defer self.allocator.free(graph_points_slice);

        Gfx.drawCurve(self.app.renderer, graph_points_slice);
    }

    pub fn drawNoPauseCheck(self: *Self, renderer: *c.SDL_Renderer) !void {
        // mouse co-ordinates
        self.mouse_pos = Input.getMousePosition(self.app.pixel_buffer_scale);
        const mouse_pos_x_trunc = @trunc(self.mouse_pos.x);
        const mouse_pos_y_trunc = @trunc(self.mouse_pos.y);
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
            try Gfx.drawFmtText(renderer, self.mouse_pos.x, self.mouse_pos.y, "{d},{d}", .{ mouse_pos_x_trunc, mouse_pos_y_trunc });
        }
        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff * 1 / 2, 0xff * 1 / 2, 0xff, 0xff));
        try self.drawCurves();

        try entity.drawTriangle(renderer, mouse_pos_x_trunc, mouse_pos_y_trunc, -8, -19);

        try errify(c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND));
        try errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff / 8));
        if (self.is_grid_shown) {
            Gfx.drawGrid(renderer, -1, -1, self.app.pixel_buffer_width, self.app.pixel_buffer_height, App.text_width, App.text_height);
        }

        const floatW = @as(f32, @floatFromInt(self.app.window_width));
        const floatH = @as(f32, @floatFromInt(self.app.window_height));
        Gfx.drawCrossHairsFullScreen(renderer, self.mouse_pos.x, self.mouse_pos.y, floatW, floatH);
    }

    pub fn draw(self: *Self, renderer: *c.SDL_Renderer) !void {
        _ = try self.drawNoPauseCheck(renderer);
        if (self.state == State.Running) {
            self.frames_drawn += 1;
        }
    }
};
