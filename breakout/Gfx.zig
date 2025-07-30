const std = @import("std");
const c = @import("cimports.zig").c;
const App = @import("app.zig").App;
const Point = @import("Point.zig");
const errify = @import("sdlglue.zig").errify;

pub inline fn drawLineHorizontal(renderer: *c.SDL_Renderer, y: f32, w: f32) void {
    _ = c.SDL_RenderLine(renderer, 0, y, w, y);
}

pub inline fn drawLineVertical(renderer: *c.SDL_Renderer, x: f32, h: f32) void {
    _ = c.SDL_RenderLine(renderer, x, 0, x, h);
}

pub fn drawCrossHairsFullScreen(renderer: *c.SDL_Renderer, x: f32, y: f32, w: f32, h: f32) void {
    drawLineHorizontal(renderer, y, w);
    drawLineVertical(renderer, x, h);
}

pub fn drawCrossHairs(renderer: *c.SDL_Renderer, x: f32, y: f32, r: f32) void {
    _ = c.SDL_RenderLine(renderer, x - r, y, x + r, y);
    _ = c.SDL_RenderLine(renderer, x, y - r, x, y + r);
}

pub fn drawGrid(renderer: *c.SDL_Renderer, x: f32, y: f32, w: f32, h: f32, pixels_per_div_x: f32, pixels_per_div_y: f32) void {
    var cursor_x: f32 = 0;
    var cursor_y: f32 = 0;
    //draw horizontals
    while (cursor_y <= h) {
        drawLineHorizontal(renderer, cursor_y + y, w);
        cursor_y += pixels_per_div_y;
    }
    cursor_y = 0;
    while (cursor_x <= w) {
        drawLineVertical(renderer, cursor_x + x, h);
        cursor_x += pixels_per_div_x;
    }
}

pub fn drawFmtText(renderer: *c.SDL_Renderer, x: f32, y: f32, comptime fmt: []const u8, args: anytype) !void {
    var textBuffer: [257]u8 = undefined;
    // Use subslice to ensure buffer has at least 1 byte of free space for the null.
    const bufferShort = textBuffer[0 .. textBuffer.len - 1];
    const textSlice = try std.fmt.bufPrint(bufferShort, fmt, args);
    // Manually add the null terminator.
    textBuffer[textSlice.len] = 0;
    // The C function will read up to the null byte we just wrote.
    _ = c.SDL_RenderDebugText(renderer, x, y, &textBuffer[0]);
}

pub fn drawRawBytes(renderer: *c.SDL_Renderer, x: f32, y: f32, bytes: []const u8) !void {
    // We need a null-terminated buffer to pass to C.
    // Let's allocate one on the stack that's big enough.
    var c_buffer: [257]u8 = undefined; // Max line length + 1 for null

    // Clamp the slice to our buffer size to prevent overflow.
    const to_copy = bytes[0..@min(bytes.len, c_buffer.len - 1)];

    // Copy the data and null-terminate it.
    @memcpy(c_buffer[0..to_copy.len], to_copy);
    c_buffer[to_copy.len] = 0;

    // Call the C function with our safe, null-terminated buffer.
    _ = c.SDL_RenderDebugText(renderer, x, y, &c_buffer[0]);
}

pub fn drawDebugTextChars(renderer: *c.SDL_Renderer, app: *App, bytes: []const u8) !void {
    // draw all debug text characters
    const maxCharsPerLine = @as(usize, @intFromFloat(app.pixel_buffer_width / App.text_width));
    //const maxCharsPerLine = 2;
    const numLines = bytes.len / maxCharsPerLine;
    const yOffset = app.pixel_buffer_height - (@trunc(@as(f32, @floatFromInt(numLines))) * App.text_height);
    var line: usize = 0;
    const charOffset = 32; //first 32 characters blank
    while (line < numLines) {
        try drawRawBytes(renderer, 0, @as(f32, @floatFromInt(line)) * App.text_height + yOffset, bytes[charOffset + maxCharsPerLine * line ..]);
        line += 1;
    }
}

pub fn drawCurve(renderer: *c.SDL_Renderer, graph_points: []const c.SDL_FPoint) void {
    for (0..(graph_points.len - 1)) |i| {
        const p1 = graph_points[i];
        const p2 = graph_points[i + 1];
        _ = c.SDL_RenderLine(renderer, p1.x, p1.y, p2.x, p2.y);
    }
}

pub fn drawPoints(renderer: *c.SDL_Renderer, points: []const c.SDL_FPoint) !void {
    _ = try errify(c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, c.SDL_ALPHA_OPAQUE));
    _ = try c.SDL_RenderPoints(renderer, points, c.SDL_arraysize(points));
}

pub fn drawTriangle(renderer: *c.SDL_Renderer) !void {
    var vertices: [4]c.SDL_Vertex = undefined;
    const size = 200.0 + (200.0 * 1);
    const WINDOW_WIDTH = 400;
    const WINDOW_HEIGHT = 300;

    //c.SDL_zeroa(vertices);
    vertices[0].position.x = (WINDOW_WIDTH) / 2;
    vertices[0].position.y = ((WINDOW_HEIGHT) - size) / 2;
    vertices[0].color.r = 1;
    vertices[0].color.a = 1;
    vertices[1].position.x = ((WINDOW_WIDTH) + size) / 2;
    vertices[1].position.y = ((WINDOW_HEIGHT) + size) / 2;
    vertices[1].color.g = 1;
    vertices[1].color.a = 1;
    vertices[2].position.x = ((WINDOW_WIDTH) - size) / 2;
    vertices[2].position.y = ((WINDOW_HEIGHT) + size) / 2;
    vertices[2].color.b = 1;
    vertices[2].color.a = 1;

    _ = c.SDL_RenderGeometry(renderer, null, &vertices, 3, null, 0);
}
