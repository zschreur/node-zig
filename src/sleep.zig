const std = @import("std");
const node = @import("./node.zig");

const c = node.c;
const nodeApiCall = node.nodeApiCall;
const checkStatus = node.checkStatus;
const getValue = node.getValue;

const allocator = node.general_purpose_allocator;

const SleepCtx = struct {
    deferred: c.napi_deferred,
    work: c.napi_async_work,
    sleep_duration_ms: u64,
};

// napi_env parameter should **NOT** be used.
// See: https://nodejs.org/docs/latest/api/n-api.html#napi_async_execute_callback
fn executeSleep(_: c.napi_env, ctx: ?*anyopaque) callconv(.c) void {
    const sleep_ctx = @as(*SleepCtx, @alignCast(@ptrCast(ctx.?)));

    std.Thread.sleep(std.time.ns_per_ms * sleep_ctx.sleep_duration_ms);
}

fn completeSleep(env: c.napi_env, status: c.napi_status, ctx: ?*anyopaque) callconv(.c) void {
    const sleep_ctx = @as(*SleepCtx, @alignCast(@ptrCast(ctx.?)));
    defer {
        nodeApiCall(c.napi_delete_async_work, .{ env, sleep_ctx.work }) catch unreachable;
        allocator.destroy(sleep_ctx);
    }

    checkStatus(status) catch unreachable;

    var res: c.napi_value = null;
    nodeApiCall(c.napi_get_undefined, .{ env, &res }) catch unreachable;
    nodeApiCall(c.napi_resolve_deferred, .{ env, sleep_ctx.deferred, res }) catch unreachable;
}

pub fn sleep(env: c.napi_env, info: c.napi_callback_info) anyerror!c.napi_value {
    const sleep_duration_ms = blk: {
        var argc: usize = 1;
        var argv = [_]c.napi_value{null};

        try nodeApiCall(c.napi_get_cb_info, .{ env, info, &argc, &argv, null, null });
        if (argc < 1) {
            _ = c.napi_throw_type_error(env, null, "Wrong number of arguments");
            return null;
        }
        break :blk @as(u64, @intCast(try getValue(i64, .{
            .env = env,
            .arg = argv[0],
        })));
    };

    var deferred: c.napi_deferred = null;
    var promise: c.napi_value = null;
    try nodeApiCall(c.napi_create_promise, .{ env, &deferred, &promise });

    var label: c.napi_value = null;
    try nodeApiCall(c.napi_create_string_utf8, .{ env, "generic", c.NAPI_AUTO_LENGTH, &label });

    // this is freed in completeSleep
    const sleep_ctx = try allocator.create(SleepCtx);

    var work: c.napi_async_work = null;
    try nodeApiCall(c.napi_create_async_work, .{
        env,
        null,
        label,
        &executeSleep,
        &completeSleep,
        @as(?*anyopaque, @alignCast(@ptrCast(sleep_ctx))),
        &work,
    });

    sleep_ctx.* = .{
        .deferred = deferred,
        .work = work,
        .sleep_duration_ms = sleep_duration_ms,
    };

    try nodeApiCall(c.napi_queue_async_work, .{ env, work });

    return promise;
}
