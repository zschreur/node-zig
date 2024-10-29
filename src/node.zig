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

fn getParamSize(func: anytype) comptime_int {
    const func_type = @typeInfo(@TypeOf(func)).@"fn";
    var paramSize = 0;
    for (func_type.params) |param| {
        paramSize += if (param.type) |t| @sizeOf(t) else 0;
    }
    return paramSize;
}
