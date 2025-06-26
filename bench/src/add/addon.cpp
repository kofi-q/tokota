/*
 * Copied from
 * https://github.com/nodejs/node-addon-examples/blob/main/src/1-getting-started/2_function_arguments/node-addon-api/addon.cc
 *
 * The MIT License (MIT)
 * Copyright (c) 2017 Node.js node-addon-examples collaborators
 */

#include <napi.h>

Napi::Value Add(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();

  double arg0 = info[0].As<Napi::Number>().DoubleValue();
  double arg1 = info[1].As<Napi::Number>().DoubleValue();
  Napi::Number num = Napi::Number::New(env, arg0 + arg1);

  return num;
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set(Napi::String::New(env, "add"), Napi::Function::New(env, Add));
  return exports;
}

NODE_API_MODULE(addon, Init)
