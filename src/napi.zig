//! This module contains the lower-level types and Node-API bindings used by the
//! abstractions provided in the main `tokota` namespace.
//!
//! Detailed documentation is available at https://nodejs.org/docs/latest/api/n-api.html.

const t = @import("root.zig");

const ext_array = @import("array/napi.zig");
const ext_array_buffer = @import("array_buffer/napi.zig");
const ext_async = @import("async/napi.zig");
const ext_date = @import("date/napi.zig");
const ext_error = @import("error/napi.zig");
const ext_function = @import("function/napi.zig");
const ext_global = @import("global/napi.zig");
const ext_heap = @import("heap/napi.zig");
const ext_lifetime = @import("lifetime/napi.zig");
const ext_number = @import("number/napi.zig");
const ext_object = @import("object/napi.zig");
const ext_string = @import("string/napi.zig");

pub const AsyncComplete = ext_async.AsyncComplete;
pub const AsyncContext = ext_async.AsyncContext;
pub const AsyncExecute = ext_async.AsyncExecute;
pub const AsyncWorker = ext_async.AsyncWorker;
pub const Callback = ext_function.Callback;
pub const CallbackScope = ext_async.CallbackScope;
pub const CallInfo = ext_function.CallInfo;
pub const cleanup = ext_heap.cleanup;
pub const FinalizeCb = ext_heap.FinalizeCb;
pub const HandleScope = ext_lifetime.HandleScope;
pub const HandleScopeEscapable = ext_lifetime.HandleScopeEscapable;
pub const Ref = ext_lifetime.Ref;
pub const Status = ext_error.Status;
pub const ThreadsafeFn = ext_async.ThreadsafeFn;
pub const ThreadsafeFnProxy = ext_async.ThreadsafeFnProxy;
pub const TypeTag = ext_object.TypeTag;

pub const napi_acquire_threadsafe_function = ext_async.napi_acquire_threadsafe_function;
pub const napi_add_async_cleanup_hook = ext_heap.napi_add_async_cleanup_hook;
pub const napi_add_env_cleanup_hook = ext_heap.napi_add_env_cleanup_hook;
pub const napi_add_finalizer = ext_object.napi_add_finalizer;
pub const napi_adjust_external_memory = ext_heap.napi_adjust_external_memory;
pub const napi_async_destroy = ext_async.napi_async_destroy;
pub const napi_async_init = ext_async.napi_async_init;
pub const napi_call_function = ext_function.napi_call_function;
pub const napi_call_threadsafe_function = ext_async.napi_call_threadsafe_function;
pub const napi_cancel_async_work = ext_async.napi_cancel_async_work;
pub const napi_check_object_type_tag = ext_object.napi_check_object_type_tag;
pub const napi_close_callback_scope = ext_async.napi_close_callback_scope;
pub const napi_close_escapable_handle_scope = ext_lifetime.napi_close_escapable_handle_scope;
pub const napi_close_handle_scope = ext_lifetime.napi_close_handle_scope;
pub const napi_coerce_to_bool = ext_global.napi_coerce_to_bool;
pub const napi_coerce_to_number = ext_number.napi_coerce_to_number;
pub const napi_coerce_to_object = ext_object.napi_coerce_to_object;
pub const napi_coerce_to_string = ext_string.napi_coerce_to_string;
pub const napi_create_array = ext_array.napi_create_array;
pub const napi_create_array_with_length = ext_array.napi_create_array_with_length;
pub const napi_create_arraybuffer = ext_array_buffer.napi_create_arraybuffer;
pub const napi_create_async_work = ext_async.napi_create_async_work;
pub const napi_create_bigint_int64 = ext_number.napi_create_bigint_int64;
pub const napi_create_bigint_uint64 = ext_number.napi_create_bigint_uint64;
pub const napi_create_bigint_words = ext_number.napi_create_bigint_words;
pub const napi_create_buffer = ext_array_buffer.napi_create_buffer;
pub const napi_create_buffer_copy = ext_array_buffer.napi_create_buffer_copy;
pub const napi_create_dataview = ext_array_buffer.napi_create_dataview;
pub const napi_create_date = ext_date.napi_create_date;
pub const napi_create_double = ext_number.napi_create_double;
pub const napi_create_error = ext_error.napi_create_error;
pub const napi_create_external = ext_heap.napi_create_external;
pub const napi_create_external_arraybuffer = ext_array_buffer.napi_create_external_arraybuffer;
pub const napi_create_external_buffer = ext_array_buffer.napi_create_external_buffer;
pub const napi_create_function = ext_function.napi_create_function;
pub const napi_create_int32 = ext_number.napi_create_int32;
pub const napi_create_int64 = ext_number.napi_create_int64;
pub const napi_create_object = ext_object.napi_create_object;
pub const napi_create_promise = ext_async.napi_create_promise;
pub const napi_create_range_error = ext_error.napi_create_range_error;
pub const napi_create_reference = ext_lifetime.napi_create_reference;
pub const napi_create_string_latin1 = ext_string.napi_create_string_latin1;
pub const napi_create_string_utf16 = ext_string.napi_create_string_utf16;
pub const napi_create_string_utf8 = ext_string.napi_create_string_utf8;
pub const napi_create_symbol = ext_global.napi_create_symbol;
pub const napi_create_threadsafe_function = ext_async.napi_create_threadsafe_function;
pub const napi_create_type_error = ext_error.napi_create_type_error;
pub const napi_create_typedarray = ext_array_buffer.napi_create_typedarray;
pub const napi_create_uint32 = ext_number.napi_create_uint32;
pub const napi_define_class = ext_object.napi_define_class;
pub const napi_define_properties = ext_object.napi_define_properties;
pub const napi_delete_async_work = ext_async.napi_delete_async_work;
pub const napi_delete_element = ext_array.napi_delete_element;
pub const napi_delete_property = ext_object.napi_delete_property;
pub const napi_delete_reference = ext_lifetime.napi_delete_reference;
pub const napi_detach_arraybuffer = ext_array_buffer.napi_detach_arraybuffer;
pub const napi_escape_handle = ext_lifetime.napi_escape_handle;
pub const napi_fatal_error = ext_error.napi_fatal_error;
pub const napi_fatal_exception = ext_error.napi_fatal_exception;
pub const napi_get_all_property_names = ext_object.napi_get_all_property_names;
pub const napi_get_and_clear_last_exception = ext_error.napi_get_and_clear_last_exception;
pub const napi_get_array_length = ext_array.napi_get_array_length;
pub const napi_get_arraybuffer_info = ext_array_buffer.napi_get_arraybuffer_info;
pub const napi_get_boolean = ext_global.napi_get_boolean;
pub const napi_get_buffer_info = ext_array_buffer.napi_get_buffer_info;
pub const napi_get_cb_info = ext_function.napi_get_cb_info;
pub const napi_get_dataview_info = ext_array_buffer.napi_get_dataview_info;
pub const napi_get_date_value = ext_date.napi_get_date_value;
pub const napi_get_element = ext_array.napi_get_element;
pub const napi_get_global = ext_global.napi_get_global;
pub const napi_get_instance_data = ext_heap.napi_get_instance_data;
pub const napi_get_last_error_info = ext_error.napi_get_last_error_info;
pub const napi_get_named_property = ext_object.napi_get_named_property;
pub const napi_get_new_target = ext_function.napi_get_new_target;
pub const napi_get_null = ext_global.napi_get_null;
pub const napi_get_property = ext_object.napi_get_property;
pub const napi_get_property_names = ext_object.napi_get_property_names;
pub const napi_get_prototype = ext_object.napi_get_prototype;
pub const napi_get_reference_value = ext_lifetime.napi_get_reference_value;
pub const napi_get_threadsafe_function_context = ext_async.napi_get_threadsafe_function_context;
pub const napi_get_typedarray_info = ext_array_buffer.napi_get_typedarray_info;
pub const napi_get_undefined = ext_global.napi_get_undefined;
pub const napi_get_value_bigint_int64 = ext_number.napi_get_value_bigint_int64;
pub const napi_get_value_bigint_uint64 = ext_number.napi_get_value_bigint_uint64;
pub const napi_get_value_bigint_words = ext_number.napi_get_value_bigint_words;
pub const napi_get_value_bool = ext_global.napi_get_value_bool;
pub const napi_get_value_double = ext_number.napi_get_value_double;
pub const napi_get_value_external = ext_heap.napi_get_value_external;
pub const napi_get_value_int32 = ext_number.napi_get_value_int32;
pub const napi_get_value_int64 = ext_number.napi_get_value_int64;
pub const napi_get_value_string_latin1 = ext_string.napi_get_value_string_latin1;
pub const napi_get_value_string_utf16 = ext_string.napi_get_value_string_utf16;
pub const napi_get_value_string_utf8 = ext_string.napi_get_value_string_utf8;
pub const napi_get_value_uint32 = ext_number.napi_get_value_uint32;
pub const napi_has_element = ext_array.napi_has_element;
pub const napi_has_named_property = ext_object.napi_has_named_property;
pub const napi_has_own_property = ext_object.napi_has_own_property;
pub const napi_has_property = ext_object.napi_has_property;
pub const napi_instanceof = ext_object.napi_instanceof;
pub const napi_is_array = ext_array.napi_is_array;
pub const napi_is_arraybuffer = ext_array_buffer.napi_is_arraybuffer;
pub const napi_is_buffer = ext_array_buffer.napi_is_buffer;
pub const napi_is_dataview = ext_array_buffer.napi_is_dataview;
pub const napi_is_date = ext_date.napi_is_date;
pub const napi_is_detached_arraybuffer = ext_array_buffer.napi_is_detached_arraybuffer;
pub const napi_is_error = ext_error.napi_is_error;
pub const napi_is_exception_pending = ext_error.napi_is_exception_pending;
pub const napi_is_promise = ext_async.napi_is_promise;
pub const napi_is_typedarray = ext_array_buffer.napi_is_typedarray;
pub const napi_make_callback = ext_async.napi_make_callback;
pub const napi_new_instance = ext_object.napi_new_instance;
pub const napi_object_freeze = ext_object.napi_object_freeze;
pub const napi_object_seal = ext_object.napi_object_seal;
pub const napi_open_callback_scope = ext_async.napi_open_callback_scope;
pub const napi_open_escapable_handle_scope = ext_lifetime.napi_open_escapable_handle_scope;
pub const napi_open_handle_scope = ext_lifetime.napi_open_handle_scope;
pub const napi_queue_async_work = ext_async.napi_queue_async_work;
pub const napi_ref_threadsafe_function = ext_async.napi_ref_threadsafe_function;
pub const napi_reference_ref = ext_lifetime.napi_reference_ref;
pub const napi_reference_unref = ext_lifetime.napi_reference_unref;
pub const napi_reject_deferred = ext_async.napi_reject_deferred;
pub const napi_release_threadsafe_function = ext_async.napi_release_threadsafe_function;
pub const napi_remove_async_cleanup_hook = ext_heap.napi_remove_async_cleanup_hook;
pub const napi_remove_env_cleanup_hook = ext_heap.napi_remove_env_cleanup_hook;
pub const napi_remove_wrap = ext_object.napi_remove_wrap;
pub const napi_resolve_deferred = ext_async.napi_resolve_deferred;
pub const napi_set_element = ext_array.napi_set_element;
pub const napi_set_instance_data = ext_heap.napi_set_instance_data;
pub const napi_set_named_property = ext_object.napi_set_named_property;
pub const napi_set_property = ext_object.napi_set_property;
pub const napi_throw = ext_error.napi_throw;
pub const napi_throw_error = ext_error.napi_throw_error;
pub const napi_throw_range_error = ext_error.napi_throw_range_error;
pub const napi_throw_type_error = ext_error.napi_throw_type_error;
pub const napi_type_tag_object = ext_object.napi_type_tag_object;
pub const napi_unref_threadsafe_function = ext_async.napi_unref_threadsafe_function;
pub const napi_unwrap = ext_object.napi_unwrap;
pub const napi_wrap = ext_object.napi_wrap;
pub const node_api_create_buffer_from_arraybuffer = ext_array_buffer.node_api_create_buffer_from_arraybuffer;
pub const node_api_create_external_string_latin1 = ext_string.node_api_create_external_string_latin1;
pub const node_api_create_external_string_utf16 = ext_string.node_api_create_external_string_utf16;
pub const node_api_create_property_key_latin1 = ext_object.node_api_create_property_key_latin1;
pub const node_api_create_property_key_utf16 = ext_object.node_api_create_property_key_utf16;
pub const node_api_create_property_key_utf8 = ext_object.node_api_create_property_key_utf8;
pub const node_api_create_syntax_error = ext_error.node_api_create_syntax_error;
pub const node_api_symbol_for = ext_global.node_api_symbol_for;
pub const node_api_throw_syntax_error = ext_error.node_api_throw_syntax_error;

pub extern fn napi_get_node_version(
    env: t.Env,
    version: *?*const t.NodeVersion,
) Status;

pub extern fn napi_get_version(env: t.Env, result: *u32) Status;

pub const UvLoop = opaque {};

pub extern fn napi_get_uv_event_loop(env: t.Env, loop: *?*const UvLoop) Status;

pub extern fn napi_run_script(env: t.Env, script: t.Val, res: *?t.Val) Status;

pub extern fn napi_strict_equals(
    env: t.Env,
    a: t.Val,
    b: t.Val,
    res: *bool,
) Status;

pub extern fn napi_typeof(env: t.Env, val: t.Val, result: *t.ValType) Status;

pub extern fn node_api_get_module_file_name(
    env: t.Env,
    result: *?[*:0]const u8,
) Status;
