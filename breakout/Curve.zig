const std = @import("std");
const c = @import("cimports.zig").c;

const TWO_PI = std.math.pi * 2;

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

pub const SineOscillator = struct {
    const Self = @This();
    amplitude: f32 = 1,
    frequency: f32,
    phase: f32 = 0,
    sample_rate: f32,

    pub fn init(amplitude: f32, phase: f32, frequency: f32, sample_rate: f32) Self {
        return Self{
            .amplitude = amplitude,
            .frequency = frequency,
            .phase = phase,
            .sample_rate = sample_rate,
        };
    }

    pub fn nextSample(self: *Self) f32 {
        const output = c.SDL_sinf(self.phase) * self.amplitude;
        // prepare the next phase value
        const phase_increment = self.frequency * TWO_PI / self.sample_rate;
        self.phase += phase_increment;
        if (self.phase >= TWO_PI) self.phase = @rem(self.phase, TWO_PI);
        return output;
    }

    pub fn setAmplitude(self: *Self, new_amplitude: f32) void {
        self.amplitude = new_amplitude;
    }

    pub fn setFrequency(self: *Self, new_frequency: f32) void {
        self.frequency = new_frequency;
    }

    pub fn setPhase(self: *Self, new_phase: f32) void {
        self.phase = new_phase;
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

pub fn generatePointsArrayFromContext(
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

pub fn generatePointsSliceFromContext(
    allocator: std.mem.Allocator,
    num_points: usize,
    context: *const anyopaque,
    y_calculator: fn (ctx: *const anyopaque, x: f32) f32, // <-- This is the function pointer type
) ![]c.SDL_FPoint {
    const points_slice = try allocator.alloc(c.SDL_FPoint, num_points);
    // Use `errdefer` to free the memory if something goes wrong *inside* this
    // function after allocation but before it successfully returns.
    errdefer allocator.free(points_slice);
    for (points_slice, 0..) |*pt, i| {
        // Cast the index to a float to pass to our calculator function
        const x = @as(f32, @floatFromInt(i));
        pt.* = c.SDL_FPoint{
            .x = x,
            .y = y_calculator(context, x), // <-- Here we call the passed-in function
        };
    }
    return points_slice;
}
