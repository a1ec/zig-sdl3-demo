const c = @import("cimports.zig").c;
const std = @import("std");

pub const std_options: std.Options = .{ .log_level = .debug };
const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

const Timekeeper = @import("timekeeper.zig").Timekeeper;
var timekeeper: Timekeeper = undefined;
const App = @import("app.zig").App;

//BLOCK Main Functions
fn sdlAppIterate(appstate: ?*anyopaque) !c.SDL_AppResult {
    while (timekeeper.consume()) {}

    const appPtr: *App = @alignCast(@ptrCast(appstate.?));
    try appPtr.updateGfx();

    timekeeper.produce(c.SDL_GetPerformanceCounter());
    return c.SDL_APP_CONTINUE;
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *c.SDL_Event) !c.SDL_AppResult {
    const appPtr: *App = @alignCast(@ptrCast(appstate.?));

    return appPtr.handleStateEvent(appPtr, event);
    //return c.SDL_APP_CONTINUE;
}

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !c.SDL_AppResult {
    _ = argv;

    const app: **App = @ptrCast(appstate);
    timekeeper = .{ .tocks_per_s = c.SDL_GetPerformanceFrequency() };

    errify(c.SDL_SetHint(c.SDL_HINT_RENDER_VSYNC, "1")) catch {};
    try errify(c.SDL_SetAppMetadata("Example", "1.0", "example.com"));
    try errify(c.SDL_Init(c.SDL_INIT_VIDEO));
    try errify(c.SDL_CreateWindowAndRenderer("examples/renderer/debug-text", app.*.window_w, app.*.window_h, 0, @alignCast(@ptrCast(&app.*.window)), @alignCast(@ptrCast(&app.*.renderer))));

    try errify(c.SDL_SetRenderScale(app.*.renderer, app.*.gameScreenScale, app.*.gameScreenScale));
    try errify(c.SDL_SetRenderDrawColor(app.*.renderer, 0x00, 0x00, 0x00, 0xff));
    try errify(c.SDL_RenderClear(app.*.renderer));
    return c.SDL_APP_CONTINUE;
}

fn sdlAppQuit(appState: ?*anyopaque, result: anyerror!c.SDL_AppResult) void {
    _ = result catch |err| if (err == error.SdlError) {
        sdl_log.err("{s}", .{c.SDL_GetError()});
    };

    const appPtr: *App = @alignCast(@ptrCast(appState.?));
    c.SDL_DestroyRenderer(appPtr.renderer);
    c.SDL_DestroyWindow(appPtr.window);
    // run your cleanup
    // free the heap allocation
    std.heap.page_allocator.destroy(appPtr);
}

//BLOCK Main Function

//BLOCK Callbacks
pub fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return c.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.SDL_AppResult {
    // 1. Unwrap the pointer‐to‐slot
    const stateSlot = appstate.?; // *?*anyopaque

    // 2. Build or allocate your App
    //    Here we use the page_allocator as an example.
    const allocator = std.heap.page_allocator;
    const appPtr = allocator.create(App) catch return c.SDL_APP_FAILURE;
    // initialize with your init fn
    appPtr.* = undefined;
    appPtr.init();

    // 3. Store it (cast to anyopaque to satisfy the C API)
    stateSlot.* = @ptrCast(appPtr);
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
// END BLOCK Callbacks

// Converts the return value of an SDL function to an error union.
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
