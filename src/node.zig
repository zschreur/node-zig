const std = @import("std");
const c = @cImport({
    @cInclude("node_api.h");
});

const NodeError = error{
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
        c.napi_ok => return {},
        c.napi_invalid_arg => return NodeError.napi_invalid_arg,
        c.napi_object_expected => return NodeError.napi_object_expected,
        c.napi_string_expected => return NodeError.napi_string_expected,
        c.napi_name_expected => return NodeError.napi_name_expected,
        c.napi_function_expected => return NodeError.napi_function_expected,
        c.napi_number_expected => return NodeError.napi_number_expected,
        c.napi_boolean_expected => return NodeError.napi_boolean_expected,
        c.napi_array_expected => return NodeError.napi_array_expected,
        c.napi_generic_failure => return NodeError.napi_generic_failure,
        c.napi_pending_exception => return NodeError.napi_pending_exception,
        c.napi_cancelled => return NodeError.napi_cancelled,
        c.napi_escape_called_twice => return NodeError.napi_escape_called_twice,
        c.napi_handle_scope_mismatch => return NodeError.napi_handle_scope_mismatch,
        c.napi_callback_scope_mismatch => return NodeError.napi_callback_scope_mismatch,
        c.napi_queue_full => return NodeError.napi_queue_full,
        c.napi_closing => return NodeError.napi_closing,
        c.napi_bigint_expected => return NodeError.napi_bigint_expected,
        c.napi_date_expected => return NodeError.napi_date_expected,
        c.napi_arraybuffer_expected => return NodeError.napi_arraybuffer_expected,
        c.napi_detachable_arraybuffer_expected => return NodeError.napi_detachable_arraybuffer_expected,
        c.napi_would_deadlock => return NodeError.napi_would_deadlock, // unused
        c.napi_no_external_buffers_allowed => return NodeError.napi_no_external_buffers_allowed,
        c.napi_cannot_run_js => return NodeError.napi_cannot_run_js,
        else => unreachable,
    }
}

fn getNodeNumber(comptime T: type, env: c.napi_env, arg: c.napi_value) !T {
    var res: T = undefined;
    switch (T) {
        f64 => try nodeApiCall(c.napi_get_value_double, .{ env, arg, &res }),
        i32 => try nodeApiCall(c.napi_get_value_int32, .{ env, arg, &res }),
        u32 => try nodeApiCall(c.napi_get_value_uint32, .{ env, arg, &res }),
        i64 => try nodeApiCall(c.napi_get_value_int64, .{ env, arg, &res }),
        else => @compileError(@typeName(T) ++ " is not implemented for getNumber"),
    }

    return res;
}

fn nodeStringSize(env: c.napi_env, arg: c.napi_value) !usize {
    var string_size: usize = 0;
    try nodeApiCall(c.napi_get_value_string_utf8, .{
        env,
        arg,
        null,
        0,
        &string_size,
    });

    return string_size;
}

fn getNodeString(allocator: std.mem.Allocator, env: c.napi_env, arg: c.napi_value) ![:0]u8 {
    var string_size = try nodeStringSize(env, arg);

    const memory = try allocator.allocSentinel(u8, string_size, 0);
    try nodeApiCall(c.napi_get_value_string_utf8, .{
        env,
        arg,
        memory,
        memory.len + 1, // 1 must be added to include the sentinel byte
        &string_size,
    });

    return memory;
}

fn getNodeBool(env: c.napi_env, arg: c.napi_value) !bool {
    var res: bool = undefined;
    try nodeApiCall(c.napi_get_value_bool, .{ env, arg, &res });
    return res;
}


fn getTypedArray(T: type, env: c.napi_env, arg: c.napi_value, length: ?comptime_int) !if (length) |l| [l]T else ([]T) {
    var is_typed_array: bool = undefined;
    try nodeApiCall(c.napi_is_typedarray, .{ env, arg, &is_typed_array });

    if (!is_typed_array) {
        return error.ExpectedTypedArrayForValue;
    }

    const expected_array_type = switch (T) {
        i8 => c.napi_int8_array,
        u8 => c.napi_uint8_array,
        // ? => c.napi_uint8_clamped_array
        i16 => c.napi_int16_array,
        u16 => c.napi_uint16_array,
        i32 => c.napi_int32_array,
        u32 => c.napi_uint32_array,
        f32 => c.napi_float32_array,
        f64 => c.napi_float64_array,
        i64 => c.napi_bigint64_array,
        u64 => c.napi_biguint64_array,
        else => {
            @compileError("getTypedArray is not implemented for " ++ @typeName(T));
        },
    };

    var typedarray_type: c.napi_typedarray_type = undefined;
    var actual_length: usize = length orelse 0;
    var data: [*]T = undefined;
    try nodeApiCall(c.napi_get_typedarray_info, .{
        env,
        arg,
        &typedarray_type,
        &actual_length,
        @as(*?*anyopaque, @alignCast(@ptrCast(&data))),
        null, // arraybuffer
        null, // byte_offset
    });

    if (typedarray_type != expected_array_type) {
        return error.IncorrectTypedArrayType;
    }

    if (length) |l| {
        if (l != actual_length) {
            return error.ExpectedFixedLengthArray;
        }
    }

    if (length) |l| {
        return data[0..l].*;
    } else {
        return data[0..actual_length];
    }
}

fn getNodeValueForZigArray(comptime ArrayType: std.builtin.Type.Array, env: c.napi_env, arg: c.napi_value) !@Type(std.builtin.Type{ .array = ArrayType }) {
    return switch (@Type((std.builtin.Type{ .array = ArrayType }))) {
        [ArrayType.len]ArrayType.child => getTypedArray(ArrayType.child, env, arg, ArrayType.len),
        else => {
            @compileError(@typeName(@Type((std.builtin.Type{ .array = ArrayType }))) ++ " is not implemented for getValue");
        },
    };
}

fn getNodeValueForPointer(comptime PointerType: std.builtin.Type.Pointer, env: c.napi_env, arg: c.napi_value, allocator: std.mem.Allocator) !@Type(std.builtin.Type{ .pointer = PointerType }) {
    const T = @Type((std.builtin.Type{ .pointer = PointerType }));
    return switch (T) {
        []PointerType.child => getTypedArray(PointerType.child, env, arg, null),
        [:0]const u8, [:0]u8 => try getNodeString(allocator, env, arg),
        else => {
            @compileError(@typeName(T) ++ " is not implemented for getValue");
        },
    };
}

fn getValue(comptime T: type, env: c.napi_env, arg: c.napi_value, allocator: std.mem.Allocator) !T {
    _ = &allocator;
    const type_info = @typeInfo(T);
    const res = switch (type_info) {
        .float, .int => try getNodeNumber(T, env, arg),
        .bool => try getNodeBool(env, arg),
        .pointer => getNodeValueForPointer(type_info.pointer, env, arg, allocator),
        .array => try getNodeValueForZigArray(type_info.array, env, arg),
        else => {
            @compileError(@typeName(T) ++ " is not implemented for getValue");
        },
    };
    return res;
}

fn createValue(comptime T: type, value: T, env: c.napi_env) NodeError!c.napi_value {
    var res: c.napi_value = undefined;
    switch (T) {
        f64, f32 => {
            try nodeApiCall(c.napi_create_double, .{ env, value, &res });
        },
        i64 => {
            try nodeApiCall(c.napi_create_int64, .{ env, value, &res });
        },
        bool => {
            try nodeApiCall(c.napi_get_boolean, .{ env, value, &res });
        },
        void => {
            try nodeApiCall(c.napi_get_undefined, .{ env, &res });
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

const NodeFunction = fn (c.napi_env, c.napi_callback_info) anyerror!c.napi_value;
pub fn nodeCall(comptime func: anytype) NodeFunction {
    const NodeReturn = ReturnType(NodeFunction);

    return struct {
        fn call(env: c.napi_env, info: c.napi_callback_info) NodeReturn {
            const func_type_info = getFuncTypeInfo(func);

            const args_type_info = @typeInfo(func_type_info.Args);
            var argc: usize = args_type_info.@"struct".fields.len;
            var args: [args_type_info.@"struct".fields.len]c.napi_value = undefined;

            try nodeApiCall(c.napi_get_cb_info, .{ env, info, &argc, &args, null, null });
            if (argc < args_type_info.@"struct".fields.len) {
                _ = c.napi_throw_type_error(env, null, "Wrong number of arguments");
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
    }.call;
}
