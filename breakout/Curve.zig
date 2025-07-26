const std = @import("std");
const c = @import("cimports.zig").c;

pub const SineWaveContext = struct {
    amplitude: f32,
    frequency: f32,
    y_offset: f32,

    // 2. Define a function that takes this context
    pub fn calc(context_ptr: *const anyopaque, x: f32) f32 {
        const self: *const SineWaveContext = @ptrCast(@alignCast(context_ptr));
        return self.y_offset + (self.amplitude * std.math.sin(x * self.frequency));
    }
};

pub const ParabolaContext = struct {
    a: f32,
    b: f32,
    c_: f32,

    // 2. Define a function that takes this context
    pub fn calc(context_ptr: *const anyopaque, x: f32) f32 {
        const self: *const ParabolaContext = @ptrCast(@alignCast(context_ptr));
        return self.a * (x * x) + self.b * x + self.c_;
    }
};

pub fn parabola(x: f32, a: f32, b: f32, c_: f32) f32 {
    // Use floating point division for a smooth curve
    return a * (x * x) + b * x + c_;
}

pub fn sine(x: f32, a: f32, b: f32, c_: f32) f32 {
    const amplitude = a;
    const frequency = b;
    // You might need to translate the result to be visible on screen
    const y_offset = c_;
    return y_offset + (amplitude * std.math.sin(x * frequency));
}

pub fn generatePointsWithContext(
    num_points: comptime_int,
    context: *const anyopaque,
    y_calculator: fn (ctx: *const anyopaque, x: f32) f32, // <-- This is the function pointer type
) [num_points]c.SDL_FPoint {
    var points: [num_points]c.SDL_FPoint = undefined;

    for (&points, 0..) |*pt, i| {
        // Cast the index to a float to pass to our calculator function
        const x = @as(f32, @floatFromInt(i));

        pt.* = c.SDL_FPoint{
            .x = x,
            .y = y_calculator(context, x), // <-- Here we call the passed-in function
        };
    }
    return points;
}
