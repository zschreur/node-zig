const node_api = @cImport({
    @cInclude("node_api.h");
});
const node = @import("./node.zig");

const napi_env = node_api.napi_env;
const napi_callback_info = node_api.napi_callback_info;
const napi_value = node_api.napi_value;

fn add(env: napi_env, info: napi_callback_info) !napi_value {
    var args: [2]napi_value = undefined; // must be var b/c of cast
    var argc: usize = 2;

    try node.nodeApiCall(node_api.napi_get_cb_info, .{ env, info, &argc, &args, null, null });

    if (argc < 2) {
        _ = node_api.napi_throw_type_error(env, null, "Wrong number of arguments");
        return null;
    }

    var valuetype0: node_api.napi_valuetype = undefined;
    try node.nodeApiCall(node_api.napi_typeof, .{ env, args[0], &valuetype0 });

    var valuetype1: node_api.napi_valuetype = undefined;
    try node.nodeApiCall(node_api.napi_typeof, .{ env, args[1], &valuetype1 });

    if (valuetype0 != node_api.napi_number or valuetype1 != node_api.napi_number) {
        _ = node_api.napi_throw_type_error(env, null, "Wrong arguments");
        return null;
    }

    var value0: f64 = undefined;
    try node.nodeApiCall(node_api.napi_get_value_double, .{ env, args[0], &value0 });

    var value1: f64 = undefined;
    try node.nodeApiCall(node_api.napi_get_value_double, .{ env, args[1], &value1 });

    var sum: napi_value = undefined;
    try node.nodeApiCall(node_api.napi_create_double, .{ env, value0 + value1, &sum });

    return sum;
}

fn declareNapiMethod(
    name: anytype,
    func: fn (napi_env, napi_callback_info) node.NodeError!napi_value,
) node_api.napi_property_descriptor {
    const method = struct {
        fn method(e: napi_env, i: napi_callback_info) callconv(.C) napi_value {
            return func(e, i) catch |err| {
                @panic(@errorName(err));
            };
        }
    }.method;

    return .{
        .utf8name = name,
        .method = method,
        .attributes = node_api.napi_default,
        .name = null,
        .getter = null,
        .setter = null,
        .value = null,
        .data = null,
    };
}

export fn Init(env: napi_env, exports: napi_value) napi_value {
    // see: https://nodejs.org/api/n-api.html#napi_property_descriptor
    var props = [_]node_api.napi_property_descriptor{
        declareNapiMethod("add", add),
    };
    node.nodeApiCall(node_api.napi_define_properties, .{ env, exports, props.len, &props }) catch |err| {
        @panic(@errorName(err));
    };

    return exports;
}
