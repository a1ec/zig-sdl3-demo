const c = @import("cimports.zig").c;
const std = @import("std");

pub const std_options: std.Options = .{ .log_level = .debug };
const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

const Timekeeper = @import("timekeeper.zig").Timekeeper;
var timekeeper: Timekeeper = undefined;

pub const MenuEvent = enum {
    Next,
    Prev,
    Select,
};

pub fn updateMenu(delta: f32) void {
    menuPosition += delta;
    menuPosition = @mod(menuPosition, 3);
    selectionRect.y = menuPosition * textHeight + 1;
}

const App = struct {
    const Self = @This();
    const State = enum {
        Menu,
        Game,
    };

    state: State,
    isRunning: bool = false,
    renderer: *c.SDL_Renderer = undefined,
    window: *c.SDL_Window = undefined,
    window_w: i32 = 640,
    window_h: i32 = 480,

    pub fn init(window_w: i32, window_h: i32) Self {
        return Self{
            .state = State.Menu,
            .window_w = window_w,
            .window_h = window_h,
        };
    }

    pub fn handleEvent(self: *Self, event: MenuEvent) void {
        switch (self.state) {
            .Menu => switch (event) {
                .Next => {
                    updateMenu(1);
                },
                .Prev => {
                    updateMenu(-1);
                },
                .Select => {
                    std.debug.print("Entering.... ", .{}); // handle enter
                },
            },
            else => {},
        }
    }
};

var app = App.init(1280, 960);

const textHeight: f32 = 10;
const textWidth: f32 = 10;
const linePad: f32 = 2;
var menuPosition: f32 = 0;
var selectionRect: c.SDL_FRect = .{
    .x = 0,
    .y = 0,
    .w = 320,
    .h = textHeight,
};

fn sdlAppIterate(appstate: ?*anyopaque) !c.SDL_AppResult {
    _ = appstate;
    while (timekeeper.consume()) {}
    try errify(c.SDL_SetRenderDrawColor(app.renderer, 0x00, 0x00, 0x00, 0xff));
    try errify(c.SDL_RenderClear(app.renderer));

    try errify(c.SDL_SetRenderDrawColor(app.renderer, 0x00, 0x00, 0xaa, 0x11));
    try errify(c.SDL_RenderFillRect(app.renderer, &selectionRect));

    try errify(c.SDL_SetRenderDrawColor(app.renderer, 0xff, 0xff, 0xff, 0x88));
    try errify(c.SDL_RenderDebugText(app.renderer, 2, 2, "SDL3"));

    try errify(c.SDL_SetRenderDrawColor(app.renderer, 0xff, 0xff, 0xff, 0x88));
    try errify(c.SDL_RenderDebugText(app.renderer, 2, 12, "How cool"));

    try errify(c.SDL_SetRenderDrawColor(app.renderer, 0xff, 0xff, 0xff, 0x88));
    try errify(c.SDL_RenderDebugText(app.renderer, 2, 22, "Quit"));

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
                    return c.SDL_APP_SUCCESS;
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

    try errify(c.SDL_SetRenderScale(app.renderer, 4, 4));
    try errify(c.SDL_SetRenderDrawColor(app.renderer, 0x00, 0x00, 0x00, 0xff));
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

// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
//#region SDL main callbacks boilerplate

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

var app_err: ErrorStore = .{};

const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: c.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = c.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    fn store(es: *ErrorStore, err: anyerror) c.SDL_AppResult {
        if (c.SDL_CompareAndSwapAtomicInt(&es.status, status_not_stored, status_storing)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = c.SDL_SetAtomicInt(&es.status, status_stored);
        }
        return c.SDL_APP_FAILURE;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (c.SDL_GetAtomicInt(&es.status) != status_stored) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};

//pub fn init_av() !void {};
//pub fn loop() !void {};
//pub fn update_display() !void {};
//pub fn quit() !void {};

// Init SDL
// Main loop
//   Process Input
//   Update Display
// Clean up
