const c = @import("cimports.zig").c;
const std = @import("std");

pub const std_options: std.Options = .{ .log_level = .debug };
const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

const Timekeeper = @import("timekeeper.zig").Timekeeper;
var timekeeper: Timekeeper = undefined;
const App = @import("app.zig").App;

//BLOCK Callbacks
fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.SDL_AppResult {
    // 1. Unwrap the pointer‐to‐slot
    const stateSlot = appstate.?; // *?*anyopaque

    // create the App object that will hold the application state
    const allocator = std.heap.page_allocator;
    const app_ptr = allocator.create(App) catch return c.SDL_APP_FAILURE;
    // initialize with your init fn
    app_ptr.* = undefined;

    app_ptr.init() catch |err| {
        // Optional but highly recommended: Log the specific error.
        std.log.err("Failed to initialize App: {s}", .{@errorName(err)});

        // CRITICAL: Clean up the memory we allocated before failing.
        allocator.destroy(app_ptr);

        // Return the C-style failure code that SDL expects.
        return c.SDL_APP_FAILURE;
    };
    // 3. Store it (cast to anyopaque to satisfy the C API)
    stateSlot.* = @ptrCast(app_ptr);
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

pub fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return c.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
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
// END BLOCK Callbacks

//BLOCK Main Functions

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !c.SDL_AppResult {
    _ = argv;

    const app_pptr: **App = @ptrCast(appstate);
    timekeeper = .{ .tocks_per_s = c.SDL_GetPerformanceFrequency() };

    try errify(c.SDL_SetAppMetadata("Example", "1.0", "example.com"));
    try errify(c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO));
    errify(c.SDL_SetHint(c.SDL_HINT_RENDER_VSYNC, "1")) catch {};

    const app_ptr = app_pptr.*;

    const spec = c.SDL_AudioSpec{
        .channels = 1,
        .format = c.SDL_AUDIO_F32,
        .freq = 8000,
    };

    app_ptr.audio_stream = try errify(c.SDL_OpenAudioDeviceStream(
        c.SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &spec,
        null,
        null,
    ));
    try errify(c.SDL_ResumeAudioStreamDevice(app_ptr.audio_stream));

    try errify(c.SDL_CreateWindowAndRenderer(
        "demo1",
        app_ptr.window_width,
        app_ptr.window_height,
        0,
        @alignCast(@ptrCast(&app_ptr.window)),
        @alignCast(@ptrCast(&app_ptr.renderer)),
    ));

    app_ptr.pixel_buffer = c.SDL_CreateTexture(
        app_ptr.renderer,
        c.SDL_PIXELFORMAT_RGBA8888,
        c.SDL_TEXTUREACCESS_TARGET,
        @as(c_int, @intFromFloat(app_ptr.pixel_buffer_width)),
        @as(c_int, @intFromFloat(app_ptr.pixel_buffer_height)),
    );
    _ = c.SDL_SetTextureScaleMode(app_ptr.pixel_buffer, c.SDL_SCALEMODE_NEAREST);

    try errify(c.SDL_SetRenderScale(app_ptr.renderer, app_ptr.pixel_buffer_scale, app_ptr.pixel_buffer_scale));
    try errify(c.SDL_SetRenderDrawColor(app_ptr.renderer, 0x00, 0x00, 0x00, 0xff));
    try errify(c.SDL_RenderClear(app_ptr.renderer));
    try errify(c.SDL_SetRenderDrawBlendMode(app_ptr.renderer, c.SDL_BLENDMODE_BLEND));
    return c.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate: ?*anyopaque) !c.SDL_AppResult {
    while (timekeeper.consume()) {}

    const app_ptr: *App = @alignCast(@ptrCast(appstate.?));
    try app_ptr.updateGfx();

    timekeeper.produce(c.SDL_GetPerformanceCounter());
    return c.SDL_APP_CONTINUE;
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *c.SDL_Event) !c.SDL_AppResult {
    const app_ptr: *App = @alignCast(@ptrCast(appstate.?));

    return app_ptr.handleStateEvent(app_ptr, event);
    //return c.SDL_APP_CONTINUE;
}

fn sdlAppQuit(appState: ?*anyopaque, result: anyerror!c.SDL_AppResult) void {
    _ = result catch |err| if (err == error.SdlError) {
        sdl_log.err("{s}", .{c.SDL_GetError()});
    };

    if (appState == null) {
        return;
    }
    const app_ptr: *App = @alignCast(@ptrCast(appState.?));
    app_ptr.game.deinit();
    c.SDL_DestroyRenderer(app_ptr.renderer);
    c.SDL_DestroyWindow(app_ptr.window);
    c.SDL_DestroyAudioStream(app_ptr.audio_stream);
    // free the heap allocation
    std.heap.page_allocator.destroy(app_ptr);
}

//BLOCK Main Function

// Converts the varying return values of the SDL functions to a Zig error union.
pub inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
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

var app_err: ErrorStore = .{};

pub const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: c.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    pub fn reset(es: *ErrorStore) void {
        _ = c.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    pub fn store(es: *ErrorStore, err: anyerror) c.SDL_AppResult {
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

    pub fn load(es: *ErrorStore) ?anyerror {
        if (c.SDL_GetAtomicInt(&es.status) != status_stored) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};
