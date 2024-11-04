const std = @import("std");
const node_api = @cImport({
    @cInclude("node_api.h");
});

pub const NodeError = error{
    napi_invalid_arg,
    napi_object_expected,
    napi_string_expected,
    napi_name_expected,
    napi_function_expected,
    napi_number_expected,
    napi_boolean_expected,
    napi_array_expected,
    napi_generic_failure,
    napi_pending_exception,
    napi_cancelled,
    napi_escape_called_twice,
    napi_handle_scope_mismatch,
    napi_callback_scope_mismatch,
    napi_queue_full,
    napi_closing,
    napi_bigint_expected,
    napi_date_expected,
    napi_arraybuffer_expected,
    napi_detachable_arraybuffer_expected,
    napi_would_deadlock,
    napi_no_external_buffers_allowed,
    napi_cannot_run_js,
};

pub fn nodeApiCall(func: anytype, args: anytype) NodeError!void {
    const status = @call(.auto, func, args);
    switch (status) {
        // see: https://nodejs.org/api/n-api.html#napi_status
        node_api.napi_ok => return {},
        node_api.napi_invalid_arg => return NodeError.napi_invalid_arg,
        node_api.napi_object_expected => return NodeError.napi_object_expected,
        node_api.napi_string_expected => return NodeError.napi_string_expected,
        node_api.napi_name_expected => return NodeError.napi_name_expected,
        node_api.napi_function_expected => return NodeError.napi_function_expected,
        node_api.napi_number_expected => return NodeError.napi_number_expected,
        node_api.napi_boolean_expected => return NodeError.napi_boolean_expected,
        node_api.napi_array_expected => return NodeError.napi_array_expected,
        node_api.napi_generic_failure => return NodeError.napi_generic_failure,
        node_api.napi_pending_exception => return NodeError.napi_pending_exception,
        node_api.napi_cancelled => return NodeError.napi_cancelled,
        node_api.napi_escape_called_twice => return NodeError.napi_escape_called_twice,
        node_api.napi_handle_scope_mismatch => return NodeError.napi_handle_scope_mismatch,
        node_api.napi_callback_scope_mismatch => return NodeError.napi_callback_scope_mismatch,
        node_api.napi_queue_full => return NodeError.napi_queue_full,
        node_api.napi_closing => return NodeError.napi_closing,
        node_api.napi_bigint_expected => return NodeError.napi_bigint_expected,
        node_api.napi_date_expected => return NodeError.napi_date_expected,
        node_api.napi_arraybuffer_expected => return NodeError.napi_arraybuffer_expected,
        node_api.napi_detachable_arraybuffer_expected => return NodeError.napi_detachable_arraybuffer_expected,
        node_api.napi_would_deadlock => return NodeError.napi_would_deadlock, // unused
        node_api.napi_no_external_buffers_allowed => return NodeError.napi_no_external_buffers_allowed,
        node_api.napi_cannot_run_js => return NodeError.napi_cannot_run_js,
        else => unreachable,
    }
}

fn getNodeNumber(comptime T: type, env: node_api.napi_env, arg: node_api.napi_value) !T {
    var res: T = undefined;
    switch (T) {
        f64 => try nodeApiCall(node_api.napi_get_value_double, .{ env, arg, &res }),
        i32 => try nodeApiCall(node_api.napi_get_value_int32, .{ env, arg, &res }),
        u32 => try nodeApiCall(node_api.napi_get_value_uint32, .{ env, arg, &res }),
        i64 => try nodeApiCall(node_api.napi_get_value_int64, .{ env, arg, &res }),
        else => @compileError(@typeName(T) ++ " is not implemented for getNumber"),
    }

    return res;
}

fn nodeStringSize(env: node_api.napi_env, arg: node_api.napi_value) !usize {
    var string_size: usize = 0;
    try nodeApiCall(node_api.napi_get_value_string_utf8, .{
        env,
        arg,
        null,
        0,
        &string_size,
    });

    return string_size;
}

fn getNodeString(allocator: std.mem.Allocator, env: node_api.napi_env, arg: node_api.napi_value) ![:0]u8 {
    var string_size = try nodeStringSize(env, arg);

    const memory = try allocator.allocSentinel(u8, string_size, 0);
    try nodeApiCall(node_api.napi_get_value_string_utf8, .{
        env,
        arg,
        memory,
        memory.len + 1, // 1 must be added to include the sentinel byte
        &string_size,
    });

    return memory;
}

fn getNodeBool(env: node_api.napi_env, arg: node_api.napi_value) !bool {
    var res: bool = undefined;
    try nodeApiCall(node_api.napi_get_value_bool, .{ env, arg, &res });
    return res;
}

pub fn getValue(comptime T: type, env: node_api.napi_env, arg: node_api.napi_value, allocator: std.mem.Allocator) !T {
    const res = switch (T) {
        f64, i32, u32, i64, i128 => try getNodeNumber(T, env, arg),
        bool => try getNodeBool(env, arg),
        [:0]const u8, [:0]u8 => try getNodeString(allocator, env, arg),
        else => @compileError(@typeName(T) ++ " is not implemented for getValue"),
    };
    return res;
}

pub fn createValue(comptime T: type, value: T, env: node_api.napi_env) NodeError!node_api.napi_value {
    var res: node_api.napi_value = undefined;
    switch (T) {
        f64 => {
            try nodeApiCall(node_api.napi_create_double, .{ env, value, &res });
        },
        i64 => {
            try nodeApiCall(node_api.napi_create_int64, .{ env, value, &res });
        },
        bool => {
            try nodeApiCall(node_api.napi_get_boolean, .{ env, value, &res });
        },
        void => {
            try nodeApiCall(node_api.napi_get_undefined, .{ env, &res });
        },
        else => @compileError(@typeName(T) ++ " is not implemented for createValue"),
    }
    return res;
}

fn ReturnType(comptime func: type) type {
    return @typeInfo(func).@"fn".return_type.?;
}

fn getFuncTypeInfo(comptime func: anytype) struct { Args: type, Return: type } {
    const Function = @TypeOf(func);
    const Args = std.meta.ArgsTuple(Function);
    const Return = ReturnType(Function);

    return .{ .Args = Args, .Return = Return };
}

fn genericNodeCall(comptime func: anytype, env: node_api.napi_env, info: node_api.napi_callback_info) !node_api.napi_value {
    const func_type_info = getFuncTypeInfo(func);

    const args_type_info = @typeInfo(func_type_info.Args);
    var argc: usize = args_type_info.@"struct".fields.len;
    var args: [args_type_info.@"struct".fields.len]node_api.napi_value = undefined;

    try nodeApiCall(node_api.napi_get_cb_info, .{ env, info, &argc, &args, null, null });
    if (argc < args_type_info.@"struct".fields.len) {
        _ = node_api.napi_throw_type_error(env, null, "Wrong number of arguments");
        return null;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var func_args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
    inline for (args_type_info.@"struct".fields, 0..) |field, i| {
        func_args[i] = try getValue(field.type, env, args[i], allocator);
    }

    if (@typeInfo(func_type_info.Return) != .error_union) {
        const res = @call(.auto, func, func_args);
        return try createValue(func_type_info.Return, res, env);
    } else {
        const Payload = @typeInfo(func_type_info.Return).error_union.payload;
        const res = try @call(.auto, func, func_args);
        return try createValue(Payload, res, env);
    }
}

const NodeFunction = fn (node_api.napi_env, node_api.napi_callback_info) anyerror!node_api.napi_value;
pub fn nodeCall(comptime func: anytype) NodeFunction {
    const NodeReturn = ReturnType(NodeFunction);

    return struct {
        fn call(env: node_api.napi_env, info: node_api.napi_callback_info) NodeReturn {
            return genericNodeCall(func, env, info);
        }
    }.call;
}
