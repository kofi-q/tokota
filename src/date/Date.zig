//! Represents a JS [Date](https://mdn.io.Date).
//!
//! Can be:
//! - Created from the current system timestamp via `Date.now()`.
//! - Extracted from an existing JS `Val` via `Val.date()`.
//! - Received as an argument in a native callback for conversion from a JS
//!   Date (via `Val.date()`).
//! - Returned from a native callback for conversion to a JS Date (via
//!   `Env.date()`).
//!
//! ## Example
//! ```zig
//! //! addon.zig
//!
//! const t = @import("tokota");
//!
//! comptime {
//!     t.exportModule(@This());
//! }
//!
//! pub fn addMillis(date: t.Date, millis: f64) !t.Date {
//!     return .{ .timestamp_ms = date.timestamp_ms + millis };
//! }
//! ```
//!
//! ```js
//! // main.js
//!
//! const assert = require("node:assert");
//! const addon = require("./addon.node");
//!
//! const now = Date.now();
//! const newDate = addon.addMillis(new Date(now), 50_000);
//! assert.deepEqual(newDate, new Date(now + 50_000));
//! ```
//!
//! https://nodejs.org/docs/latest/api/n-api.html#napi_get_date_value

const std = @import("std");

const Env = @import("../root.zig").Env;
const Val = @import("../root.zig").Val;

const Date = @This();

/// Unix timestamp, in milliseconds.
timestamp_ms: f64,

/// Creates a new `Date` from the current system timestamp.
pub fn now() Date {
    return .{ .timestamp_ms = @floatFromInt(std.time.milliTimestamp()) };
}

/// Creates a new `Date` from the given nanosecond timestamp.
pub fn fromTimestampNs(ns: i128) Date {
    return .{ .timestamp_ms = @floatFromInt(@divFloor(ns, std.time.ns_per_ms)) };
}
