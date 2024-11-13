const std = @import("std");
const node = @import("./node.zig");

fn add(a: f64, b: f64) f64 {
    return a + b;
}

fn addOne(a: i64) i64 {
    return a + 1;
}

fn hello(s: [:0]const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, {s}!\n", .{s});
}

fn rms(nums: []f32) f32 {
    if (nums.len == 0) {
        return std.math.nan(f32);
    }

    var sum: f32 = 0;
    for (nums) |num| {
        sum += num * num;
    }

    return std.math.sqrt(sum / @as(f32, @floatFromInt(nums.len)));
}

fn audiateMicObserverFastRms(squares: [100]f32) f32 {
    @setFloatMode(.optimized);

    const v: @Vector(100, f32) = squares;
    return std.math.sqrt(@reduce(.Add, v * v) / 100);
}

comptime {
    node.registerModule(&.{
        .{ .name = "add", .function = add },
        .{ .name = "addOne", .function = addOne },
        .{ .name = "hello", .function = hello },
        .{ .name = "rms", .function = rms },
        .{ .name = "micRms", .function = audiateMicObserverFastRms },
    });
}
