const Env = @import("../root.zig").Env;
const Finalizer = @import("../root.zig").Finalizer;
const n = @import("../napi.zig");
const Ref = @import("../root.zig").Ref;
const Val = @import("../root.zig").Val;

/// Represents a JS [TypedArray](https://mdn.io/TypedArray).
///
/// Can be:
/// - Created from an existing `ArrayBuffer` - `ArrayBuffer.typedArray()`
/// - Created from a newly allocated `ArrayBuffer` - `Env.typedArray()`
/// - Extracted from an existing JS `Val` - `Val.typedArray()`
/// - Copied from a native array/slice - `Env.typedArrayFrom()`
/// - Received as an argument in a native callback.
pub fn TypedArray(comptime data_type: ArrayType) type {
    const T = data_type.Zig();

    return struct {
        const Self = @This();

        /// Handle to the backing JS `ArrayBuffer` for this `TypedArray`.
        ///
        /// More info can be retrieved via
        /// [`buffer.arrayBuffer()`](#tokota.array_buffer.Val.arrayBuffer).
        buffer: Val,

        /// The offset from the start of `buffer` from which this `DataView` begins.
        ///
        /// i.e. `data[0..]` is equivalent to `buffer[buffer_offset..][0..data.len]`.
        buffer_offset: usize,

        /// The underlying data.
        data: []T,

        /// The Node environment in which the `TypedArray` was created.
        env: Env,

        /// The handle to the JS value for this `TypedArray`.
        ptr: Val,

        /// Registers a function to be called when the underlying JS value gets
        /// garbage-collected. Enables cleanup of native values whose lifetime
        /// should be tied to the JS TypedArray.
        ///
        /// This API can be called multiple times on a single JS value.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_add_finalizer
        pub fn addFinalizer(self: Self, finalizer: Finalizer) !Ref(Self) {
            var ref_ptr: ?Ref(Self) = null;
            try n.napi_add_finalizer(
                self.env,
                self.ptr,
                finalizer.data,
                finalizer.cb.?,
                finalizer.hint,
                &ref_ptr,
            ).check();

            return ref_ptr.?;
        }

        pub fn fromJs(env: Env, val: Val) !Self {
            return val.typedArray(env, data_type);
        }

        /// Creates a `Ref` from which the `TypedArray` can later be extracted,
        /// outside of the function scope within which it was initially created
        /// or received.
        ///
        /// > #### ⚠ NOTE
        /// > References prevent a JS value from being garbage collected. A
        /// corresponding call to `Ref.unref()` or `Ref.delete()` is necessary for
        /// proper disposal.
        ///
        /// https://nodejs.org/docs/latest/api/n-api.html#napi_create_reference
        pub fn ref(self: Self, initial_ref_count: u32) !Ref(Self) {
            var ptr: ?Ref(Self) = null;
            try n.napi_create_reference(
                self.env,
                self.ptr,
                initial_ref_count,
                &ptr,
            ).check();

            return ptr.?;
        }

        pub fn toJs(self: Self, _: Env) Val {
            return self.ptr;
        }
    };
}

/// `TypedArray` element data type.
///
/// https://nodejs.org/docs/latest/api/n-api.html#napi_typedarray_type
pub const ArrayType = enum(c_int) {
    i8 = 0,

    u8 = 1,

    /// Clamped, unsigned, 8-bit integers. Any values inserted, JS-side, that
    /// fall outside of the range `0-255` will be clamped to the range limits
    /// (`0` for negative numbers, `255` for positive ones).
    u8c = 2,

    i16 = 3,

    u16 = 4,

    i32 = 5,

    u32 = 6,

    f32 = 7,

    f64 = 8,

    /// Signed, 64-bit `BigInt` elements.
    i64 = 9,

    /// Unsigned, 64-bit `BigInt` elements.
    u64 = 10,

    /// Size, in bytes, of an element of the `TypedArray` type.
    pub fn size(self: ArrayType) comptime_int {
        return switch (self) {
            .i8 => 1,
            .u8 => 1,
            .u8c => 1,
            .i16 => 2,
            .u16 => 2,
            .i32 => 4,
            .u32 => 4,
            .f32 => 4,
            .f64 => 8,
            .i64 => 8,
            .u64 => 8,
        };
    }

    /// The corresponding Zig type for the `TypedArray` type.
    pub inline fn Zig(self: ArrayType) type {
        return switch (self) {
            .i8 => i8,
            .u8 => u8,
            .u8c => u8,
            .i16 => i16,
            .u16 => u16,
            .i32 => i32,
            .u32 => u32,
            .f32 => f32,
            .f64 => f64,
            .i64 => i64,
            .u64 => u64,
        };
    }

    /// The corresponding `ArrayType` for the given single-element or
    /// slice/array type.
    pub inline fn from(comptime ElemOrCollectionType: type) ArrayType {
        const Elem = comptime switch (@typeInfo(ElemOrCollectionType)) {
            .array => |array_info| array_info.child,

            .pointer => |ptr_info| switch (ptr_info.size) {
                .one => switch (@typeInfo(ptr_info.child)) {
                    .array => |array_info| array_info.child,
                    else => @compileError(
                        @typeName(ElemOrCollectionType) ++
                            \\ has no equivalent TypedArray type.
                            \\
                        ,
                    ),
                },

                .slice => ptr_info.child,

                else => @compileError(
                    @typeName(ElemOrCollectionType) ++
                        \\ has no equivalent TypedArray type.
                        \\
                    ,
                ),
            },

            .type => ElemOrCollectionType,

            else => @compileError(
                @typeName(ElemOrCollectionType) ++
                    \\ has no equivalent TypedArray type.
                    \\
                ,
            ),
        };

        return comptime switch (Elem) {
            f32 => .f32,
            f64 => .f64,
            i16 => .i16,
            i32 => .i32,
            i64 => .i64,
            i8 => .i8,
            u16 => .u16,
            u32 => .u32,
            u64 => .u64,
            u8 => .u8,
            else => @compileError(
                @typeName(ElemOrCollectionType) ++
                    \\ has no equivalent TypedArray element type.
                    \\
                ,
            ),
        };
    }
};
