const Val = @import("../root.zig").Val;

pub const StrLatin1Owned = struct {
    /// Indicates whether or not the string was copied by the Node engine. If
    /// `true`, the backing native string can be freed, if necessary.
    copied: bool,

    /// The addon-owned backing data for the string, as specified in
    /// `Env.strLatin1Owned()`.
    data: [:0]const u8,

    /// Pointer to the JS `String` value.
    ptr: Val,
};

pub const StrUtf16Owned = struct {
    /// Indicates whether or not the string was copied by the Node engine. If
    /// `true`, the backing native string can be freed, if necessary.
    copied: bool,

    /// The addon-owned backing data for the string, as specified in
    /// `Env.strUtf16Owned()`.
    data: [:0]const u16,

    /// Pointer to the JS `String` value.
    ptr: Val,
};
