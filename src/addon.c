#include <node_api.h>
#include <stdio.h>

extern napi_value Init(napi_env env, napi_value exports);

NAPI_MODULE("addon", Init)
