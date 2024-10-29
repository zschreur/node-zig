const node_api = @cImport({
    @cInclude("node_api.h");
});
const node = @import("./node.zig");

const napi_env = node_api.napi_env;
const napi_callback_info = node_api.napi_callback_info;
const napi_value = node_api.napi_value;

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

fn add(a: f64, b: f64) f64 {
    return a + b;
}

fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

fn floatMax(a: f64, b: f64) f64 {
    return max(f64, a, b);
}

export fn Init(env: napi_env, exports: napi_value) napi_value {
    // see: https://nodejs.org/api/n-api.html#napi_property_descriptor
    var props = [_]node_api.napi_property_descriptor{
        declareNapiMethod("add", node.nodeCall(add)),
        declareNapiMethod("max", node.nodeCall(floatMax)),
    };

    node.nodeApiCall(node_api.napi_define_properties, .{ env, exports, props.len, &props }) catch |err| {
        @panic(@errorName(err));
    };

    return exports;
}
