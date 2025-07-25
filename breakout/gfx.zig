const std = @import("std");
const c = @import("cimports.zig").c;
const App = @import("app.zig").App;

pub inline fn drawLineHorizontal(y: f32, w: f32, renderer: *c.SDL_Renderer) void {
    _ = c.SDL_RenderLine(renderer, 0, y, w, y);
}

pub inline fn drawLineVertical(x: f32, h: f32, renderer: *c.SDL_Renderer) void {
    _ = c.SDL_RenderLine(renderer, x, 0, x, h);
}

pub fn drawCrossHairsFullScreen(x: f32, y: f32, w: f32, h: f32, renderer: *c.SDL_Renderer) void {
    drawLineHorizontal(y, w, renderer);
    drawLineVertical(x, h, renderer);
}

pub fn drawCrossHairs(x: f32, y: f32, r: f32, renderer: *c.SDL_Renderer) void {
    _ = c.SDL_RenderLine(renderer, x - r, y, x + r, y);
    _ = c.SDL_RenderLine(renderer, x, y - r, x, y + r);
}

pub fn drawGrid(x: f32, y: f32, w: f32, h: f32, divX: f32, divY: f32, renderer: *c.SDL_Renderer) void {
    var cursorX: f32 = 0;
    var cursorY: f32 = 0;
    //draw horizontals
    while (cursorY <= h) {
        drawLineHorizontal(cursorY + y, w, renderer);
        cursorY += divY;
    }
    cursorY = 0;
    while (cursorX <= w) {
        drawLineVertical(cursorX + x, h, renderer);
        cursorX += divX;
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
    const maxCharsPerLine = @as(usize, @intFromFloat(app.pixelBufferWidth / App.textWidth));
    //const maxCharsPerLine = 2;
    const numLines = bytes.len / maxCharsPerLine;
    const yOffset = app.pixelBufferHeight - (@trunc(@as(f32, @floatFromInt(numLines))) * App.textHeight);
    var line: usize = 0;
    const charOffset = 32; //first 32 characters blank
    while (line < numLines) {
        try drawRawBytes(renderer, 0, @as(f32, @floatFromInt(line)) * App.textHeight + yOffset, bytes[charOffset + maxCharsPerLine * line ..]);
        line += 1;
    }
}
