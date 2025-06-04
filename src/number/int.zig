const std = @import("std");

/// The [minimum safe integer](https://mdn.io/Number/MIN_SAFE_INTEGER) that can
/// be represented by a JS `Number` type. Integer values less than this are
/// not guaranteed to convert exactly/correctly to JS.
///
/// Consider using a `BigInt` instead for smaller integers.
pub const int_safe_min: comptime_int = -int_safe_max;

/// The [maximum safe integer](https://mdn.io/Number/MAX_SAFE_INTEGER) that can
/// be represented by a JS `Number` type. Integer values greater than this are
/// not guaranteed to convert exactly/correctly to JS.
///
/// Consider using a `BigInt` instead for larger integers.
pub const int_safe_max: comptime_int = std.math.maxInt(u53);

/// The widest int type available for representing ints safely in JS.
///
/// > #### ⚠ NOTE
/// > This is currently overly restrictive at 53 bits, since an i54
/// would allow `int_safe_min - 1` as a valid value.
/// Hoping https://github.com/ziglang/zig/issues/3806 has a future, which would
/// enable representing this more accurately as a `[int_safe_min, int_safe_max]`
/// ranged type.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn min(a: t.Int, b: t.Int) t.Int {
///     return @min(a, b);
/// }
/// ```
pub const Int = i53;

/// The widest int type available for representing unsigned ints safely in JS.
///
/// ## Example
/// ```zig
/// const t = @import("tokota");
///
/// comptime {
///     t.exportModule(@This());
/// }
///
/// pub fn max(a: t.Uint, b: t.Uint) t.Uint {
///     return @max(a, b);
/// }
/// ```
pub const Uint = u53;
