const node_api = @cImport({
    @cInclude("node_api.h");
});

const assert = @import("std").debug.assert;

const napi_status = node_api.napi_status;
const napi_env = node_api.napi_env;
const napi_callback_info = node_api.napi_callback_info;
const napi_value = node_api.napi_value;

fn add(env: napi_env, info: napi_callback_info) callconv(.C) napi_value {
    var args: [2]napi_value = undefined; // must be var b/c of cast
    var argc: usize = 2;
    var status: node_api.napi_status = undefined;

    status = node_api.napi_get_cb_info(env, info, &argc, &args, null, null);
    assert(status == node_api.napi_ok);

    if (argc < 2) {
        _ = node_api.napi_throw_type_error(env, null, "Wrong number of arguments");
        return null;
    }

    var valuetype0: node_api.napi_valuetype = undefined;
    status = node_api.napi_typeof(env, args[0], &valuetype0);
    assert(status == node_api.napi_ok);

    var valuetype1: node_api.napi_valuetype = undefined;
    status = node_api.napi_typeof(env, args[1], &valuetype1);
    assert(status == node_api.napi_ok);

    if (valuetype0 != node_api.napi_number or valuetype1 != node_api.napi_number) {
        _ = node_api.napi_throw_type_error(env, null, "Wrong arguments");
        return null;
    }

    var value0: f64 = undefined;
    status = node_api.napi_get_value_double(env, args[0], &value0);
    assert(status == node_api.napi_ok);

    var value1: f64 = undefined;
    status = node_api.napi_get_value_double(env, args[1], &value1);
    assert(status == node_api.napi_ok);

    var sum: napi_value = undefined;
    status = node_api.napi_create_double(env, value0 + value1, &sum);
    assert(status == node_api.napi_ok);

    return sum;
}

fn declareNapiMethod(name: anytype, func: node_api.napi_callback) node_api.napi_property_descriptor {
    return .{
        .utf8name = name,
        .method = func,
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
    var addDescriptor = declareNapiMethod("add", add);

    const status = node_api.napi_define_properties(env, exports, 1, &addDescriptor);
    assert(status == node_api.napi_ok);

    return exports;
}
