const std = @import("std");
const print = std.debug.print;
const c = @import("cimports.zig").c;
const errify = @import("sdlglue.zig").errify;

// TODO: texture 16x24
//

pub const PlayerShip = struct {
    x: f32 = 0,
    y: f32 = 0,
    rotation: f64 = 0,
    texture: *c.SDL_Texture = undefined,
    const model = [_]c.SDL_Vertex{ // 0
        .{ .position = .{ .x = 2, .y = 0 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
        .{ .position = .{ .x = 0, .y = 12 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
        .{ .position = .{ .x = 4, .y = 12 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
    };

    pub fn init(renderer: *c.SDL_Renderer) !PlayerShip {
        const aTexture = try bakeGeometryTexture(renderer);
        return PlayerShip{
            .texture = aTexture,
        };
    }
};

fn bakeGeometryTexture(renderer: *c.SDL_Renderer) !*c.SDL_Texture {
    // rasterise the geometry into a texture
    const SHIP_TEXTURE_WIDTH = 4;
    const SHIP_TEXTURE_HEIGHT = 12;

    //_ = c.SDL_ClearError();
    // Create a new texture that we can render to
    print("1 - CreateTexture:\n", .{});
    const shipTexture = null;
    shipTexture = try errify(c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_TARGET, SHIP_TEXTURE_WIDTH, SHIP_TEXTURE_HEIGHT));
    if (shipTexture == null) {
        const sdlError = c.SDL_GetError();
        std.debug.print("SDL_CreateTexture failed: {s}\n", .{sdlError});
        return error.SdlError;
    } else {
        //try errify(c.SDL_SetTextureBlendMode(shipTexture, c.SDL_BLENDMODE_BLEND));
        print("2 - GetRenderTarget:\n", .{});
    }
    const prevRenderTarget = try errify(c.SDL_GetRenderTarget(renderer));
    print("3 - SetRenderTarget:\n", .{});

    try errify(c.SDL_SetRenderTarget(renderer, shipTexture));
    // Clear the texture with *transparent black*
    try errify(c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0));
    try errify(c.SDL_RenderClear(renderer));
    try errify(c.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255));
    // Center the ship geometry within the texture
    // The center of our texture is (8, 11)
    const center_x = SHIP_TEXTURE_WIDTH / 2.0;
    const center_y = SHIP_TEXTURE_HEIGHT / 2.0;

    var centeredVertices: [PlayerShip.model.len]c.SDL_Vertex = undefined;
    for (PlayerShip.model, 0..) |v, i| {
        centeredVertices[i] = v;
        centeredVertices[i].position.x = v.position.x + center_x;
        centeredVertices[i].position.y = v.position.y + center_y;
    }
    // Render the centered geometry onto the texture
    _ = c.SDL_RenderGeometry(renderer, null, &centeredVertices[0], centeredVertices.len, null, 0);
    // Reset the render target back to the previous (pixel buffer)
    try errify(c.SDL_SetRenderTarget(renderer, prevRenderTarget));

    return shipTexture;
}

pub fn generateCharacterBytes() [256]u8 {
    var buffer: [256]u8 = undefined;
    for (0..255) |i| {
        buffer[i] = @intCast(i + 1);
    }
    buffer[255] = 0;
    return buffer;
}

pub fn drawTriangle(renderer: *c.SDL_Renderer, pos_x: f32, pos_y: f32, size_x: f32, size_y: f32) !void {
    var vertices: [3]c.SDL_Vertex = undefined;
    vertices[0].position.x = -size_x / 2 + pos_x;
    vertices[0].position.y = -size_y / 2 + pos_y;
    vertices[0].color.r = 1;
    vertices[0].color.g = 1;
    vertices[0].color.a = 1;
    vertices[1].position.x = size_x / 2 + pos_x;
    vertices[1].position.y = -size_y / 2 + pos_y;
    vertices[1].color.r = 1;
    vertices[1].color.g = 1;
    vertices[1].color.a = 1;
    vertices[2].position.x = pos_x;
    vertices[2].position.y = size_y / 2 + pos_y;
    vertices[2].color.g = 1;
    vertices[2].color.r = 1;
    vertices[2].color.a = 1;
    _ = c.SDL_RenderGeometry(renderer, null, &vertices, 3, null, 0);
}

pub fn drawTriangleTest(renderer: *c.SDL_Renderer) !void {
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
