const n = @import("../napi.zig");
const t = @import("../root.zig");

/// https://nodejs.org/docs/latest/api/n-api.html#napi_type_tag
pub const TypeTag = extern struct {
    lower: u64,
    upper: u64,
};

pub extern fn napi_add_finalizer(
    env: t.Env,
    js_object: t.Val,
    data: ?t.AnyPtrConst,
    cb: n.FinalizeCb,
    hint: ?t.AnyPtrConst,
    result: *?n.Ref,
) n.Status;

pub extern fn napi_check_object_type_tag(
    env: t.Env,
    val: t.Val,
    type_tag: *const t.Object.Tag,
    res: *bool,
) n.Status;

pub extern fn napi_coerce_to_object(
    env: t.Env,
    val: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_create_object(env: t.Env, res: *?t.Val) n.Status;

pub extern fn napi_define_class(
    env: t.Env,
    name_ptr: [*]const u8,
    name_len: usize,
    constructor: n.Callback,
    constructor_data: ?t.AnyPtrConst,
    property_count: usize,
    properties: [*]const t.Property,
    res: *?t.Val,
) n.Status;

pub extern fn napi_define_properties(
    env: t.Env,
    object: t.Val,
    property_count: usize,
    properties: [*]const t.Property,
) n.Status;

pub extern fn napi_delete_property(
    env: t.Env,
    object: t.Val,
    key: t.Val,
    result: ?*bool,
) n.Status;

pub extern fn napi_get_all_property_names(
    env: t.Env,
    object: t.Val,
    key_mode: t.Object.KeyCollectionMode,
    key_filter: t.Object.KeyFilter,
    key_conversion: t.Object.KeyConversion,
    res: *?t.Val,
) n.Status;

pub extern fn napi_get_named_property(
    env: t.Env,
    object: t.Val,
    key: [*:0]const u8,
    val: *?t.Val,
) n.Status;

pub extern fn napi_get_property_names(
    env: t.Env,
    object: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_get_property(
    env: t.Env,
    object: t.Val,
    key: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_get_prototype(
    env: t.Env,
    object: t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_has_named_property(
    env: t.Env,
    object: t.Val,
    key: [*:0]const u8,
    res: *bool,
) n.Status;

pub extern fn napi_has_own_property(
    env: t.Env,
    object: t.Val,
    key: t.Val,
    res: *bool,
) n.Status;

pub extern fn napi_has_property(
    env: t.Env,
    object: t.Val,
    key: t.Val,
    res: *bool,
) n.Status;

pub extern fn napi_instanceof(
    env: t.Env,
    object: t.Val,
    constructor: t.Val,
    res: *bool,
) n.Status;

pub extern fn napi_new_instance(
    env: t.Env,
    constructor: t.Val,
    argc: usize,
    argv: [*]const t.Val,
    res: *?t.Val,
) n.Status;

pub extern fn napi_object_freeze(env: t.Env, object: t.Val) n.Status;

pub extern fn napi_object_seal(env: t.Env, object: t.Val) n.Status;

pub extern fn napi_remove_wrap(
    env: t.Env,
    js_object: t.Val,
    result: *?t.AnyPtr,
) n.Status;

pub extern fn napi_set_named_property(
    env: t.Env,
    object: t.Val,
    key: [*:0]const u8,
    val: ?t.Val,
) n.Status;

pub extern fn napi_set_property(
    env: t.Env,
    object: t.Val,
    key: t.Val,
    val: ?t.Val,
) n.Status;

pub extern fn napi_type_tag_object(
    env: t.Env,
    val: t.Val,
    type_tag: *const t.Object.Tag,
) n.Status;

pub extern fn napi_unwrap(
    env: t.Env,
    js_object: t.Val,
    result: *?t.AnyPtr,
) n.Status;

pub extern fn napi_wrap(
    env: t.Env,
    js_object: t.Val,
    native_object: t.AnyPtrConst,
    finalize_cb: ?n.FinalizeCb,
    finalize_hint: ?t.AnyPtrConst,
    result: ?*?n.Ref,
) n.Status;

pub extern fn node_api_create_property_key_latin1(
    env: t.Env,
    str: [*]const u8,
    length: usize,
    res: *?t.Val,
) n.Status;

pub extern fn node_api_create_property_key_utf16(
    env: t.Env,
    str: [*]const u16,
    length: usize,
    res: *?t.Val,
) n.Status;

pub extern fn node_api_create_property_key_utf8(
    env: t.Env,
    str: [*]const u8,
    length: usize,
    res: *?t.Val,
) n.Status;
