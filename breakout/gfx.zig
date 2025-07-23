const c = @import("cimports.zig").c;

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
