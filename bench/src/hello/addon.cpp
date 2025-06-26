/*
 * Copied from
 * https://github.com/nodejs/node-addon-examples/blob/main/src/1-getting-started/1_hello_world/node-addon-api/hello.cc
 *
 * The MIT License (MIT)
 * Copyright (c) 2017 Node.js node-addon-examples collaborators
 */

#include <napi.h>

Napi::String Method(const Napi::CallbackInfo &info) {
  Napi::Env env = info.Env();
  return Napi::String::New(env, "world");
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
  exports.Set(Napi::String::New(env, "hello"),
              Napi::Function::New(env, Method));
  return exports;
}

NODE_API_MODULE(hello, Init)
