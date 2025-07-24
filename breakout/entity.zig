const c = @import("cimports.zig").c;
const errify = @import("sdlglue.zig").errify;

// TODO: texture 16x24
//

pub const PlayerShip = struct {
    x: f32 = 0,
    y: f32 = 0,
    rotation: f64 = 0,
    texture: *c.SDL_Texture = undefined,
    const model = [_]c.SDL_Vertex{
        .{ .position = .{ .x = 0, .y = -12 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
        .{ .position = .{ .x = -8, .y = 12 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
        .{ .position = .{ .x = 8, .y = 12 }, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 }, .tex_coord = .{ .x = 0, .y = 0 } },
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
    const SHIP_TEXTURE_WIDTH = 16;
    const SHIP_TEXTURE_HEIGHT = 24;

    // Create a new texture that we can render to
    const shipTexture = try errify(c.SDL_CreateTexture(renderer, c.SDL_PIXELFORMAT_RGBA8888, c.SDL_TEXTUREACCESS_TARGET, SHIP_TEXTURE_WIDTH, SHIP_TEXTURE_HEIGHT));
    try errify(c.SDL_SetTextureBlendMode(shipTexture, c.SDL_BLENDMODE_BLEND));

    const prevRenderTarget = try errify(c.SDL_GetRenderTarget(renderer));

    // Temporarily set the render target to our new texture
    try errify(c.SDL_SetRenderTarget(renderer, shipTexture));

    // Clear the texture with *transparent black*
    try errify(c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0));
    try errify(c.SDL_RenderClear(renderer));

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

    // IMPORTANT: Reset the render target back to the previous (pixel buffer)
    try errify(c.SDL_SetRenderTarget(renderer, prevRenderTarget));

    return shipTexture;
}

fn generateCharacterBytes() [256]u8 {
    var buffer: [256]u8 = undefined;
    for (0..255) |i| {
        buffer[i] = @intCast(i + 1);
    }
    buffer[255] = 0;
    return buffer;
}
