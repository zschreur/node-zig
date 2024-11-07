const std = @import("std");
const c = @cImport({
    @cInclude("node_api.h");
});
const node = @import("./node.zig");

fn declareNapiMethod(
    name: anytype,
    func: fn (c.napi_env, c.napi_callback_info) anyerror!c.napi_value,
) c.napi_property_descriptor {
    const method = struct {
        fn method(e: c.napi_env, i: c.napi_callback_info) callconv(.C) c.napi_value {
            return func(e, i) catch |err| {
                std.debug.dumpStackTrace(@errorReturnTrace().?.*);
                node.nodeApiCall(c.napi_throw_error, .{
                    e,
                    null,
                    @errorName(err),
                }) catch |unrecoverable_error| {
                    @panic(@errorName(unrecoverable_error));
                };

                return null;
            };
        }
    }.method;

    return .{
        .utf8name = name,
        .method = method,
        .attributes = c.napi_default,
        .name = null,
        .getter = null,
        .setter = null,
        .value = null,
        .data = null,
    };
}

fn add(a: f64, b: f64) f64 {
    return a + b;
}

fn addOne(a: f64) f64 {
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

    @setFloatMode(.optimized);
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

export fn init(env: c.napi_env, exports: c.napi_value) c.napi_value {
    // see: https://nodejs.org/api/n-api.html#napi_property_descriptor
    var props = [_]c.napi_property_descriptor{
        declareNapiMethod("add", node.nodeCall(add)),
        declareNapiMethod("addOne", node.nodeCall(addOne)),
        declareNapiMethod("hello", node.nodeCall(hello)),
        declareNapiMethod("rms", node.nodeCall(rms)),
        declareNapiMethod("micRms", node.nodeCall(audiateMicObserverFastRms)),
    };

    node.nodeApiCall(c.napi_define_properties, .{ env, exports, props.len, &props }) catch |err| {
        @panic(@errorName(err));
    };

    return exports;
}
