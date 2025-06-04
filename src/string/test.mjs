import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../testing/runner.mjs";
const { Latin1, TinyStr, Utf8, Utf16 } = createRequire(import.meta.url)(
  "./test.addon",
);

describe("latin-1 strings", () => {
  test("create", () => {
    assert.equal(Latin1.create("foo"), "foo");
    assert.notEqual(Latin1.create("❌"), "❌");
  });

  test("create - native-owned", () => {
    switch (RUNTIME) {
      case "deno":
        console.error("🚨 [SKIP] Deno: External strings not supported");
        return;

      default:
        break;
    }

    const result = Latin1.createOwned();
    const str = result.str;
    assert.equal(str, "foo");

    result.updateOwnedStr();
    assert.equal(str, "bar");
  });

  test("extract", () => {
    assert.equal(Latin1.extractBuf("foo"), "foo");
    assert.equal(Latin1.extractBuf("way too long"), "way too ");

    assert.equal(Latin1.extractN("foo"), "foo");
    assert.equal(Latin1.extractN("way too long"), "way too ");

    assert.equal(Latin1.extractAlloc("foo"), "foo");
    assert.equal(Latin1.extractAlloc("way too long"), "way too long");

    assert.notEqual(Latin1.extractBuf("❌"), "❌");
  });

  test("len", () => {
    assert.equal(Latin1.len("foo"), 3);
    assert.equal(Latin1.len("0123456789"), 10);
  });
});

describe("utf-8 strings", () => {
  test("create", () => {
    assert.equal(Utf8.create("foo"), "foo");
    assert.equal(Utf8.create("❌"), "❌");
  });

  test("extract", () => {
    assert.equal(Utf8.extractBuf("foo"), "foo");
    assert.equal(Utf8.extractBuf("way too long"), "way too ");

    assert.equal(Utf8.extractN("foo"), "foo");
    assert.equal(Utf8.extractN("way too long"), "way too ");

    assert.equal(Utf8.extractAlloc("foo"), "foo");
    assert.equal(Utf8.extractAlloc("way too long"), "way too long");

    assert.equal(Utf8.extractBuf("❌"), "❌");
  });

  test("len", () => {
    assert.equal(Utf8.len("foo"), 3);
    assert.equal(Utf8.len("0123456789"), 10);
  });
});

describe("utf-16 strings", () => {
  test("create", () => {
    assert.equal(Utf16.create("👋🏿 te tɛŋŋ?"), "👋🏿 te tɛŋŋ?");
  });

  test("create - native-owned", () => {
    switch (RUNTIME) {
      case "deno":
        console.error("🚨 [SKIP] Deno: External strings not supported");
        return;

      default:
        break;
    }

    const result = Utf16.createOwned();
    const str = result.str;
    assert.equal(str, "🟨🐧");

    result.updateOwnedStr();
    assert.equal(str, "🟩🐧");
  });

  test("extract", () => {
    assert.equal(Utf16.extractBuf("👋🏿 te tɛŋŋ?"), "👋🏿 te tɛŋŋ?");
    assert.equal(Utf16.extractBuf("0123456789ab c"), "0123456789ab ");

    assert.equal(Utf16.extractN("👋🏿 te tɛŋŋ?"), "👋🏿 te tɛŋŋ?");
    assert.equal(Utf16.extractN("0123456789ab c"), "0123456789ab ");

    assert.equal(Utf16.extractAlloc("👋🏿 te tɛŋŋ?"), "👋🏿 te tɛŋŋ?");
    assert.equal(Utf16.extractAlloc("0123456789ab c"), "0123456789ab c");
  });

  test("len", () => {
    assert.equal(Utf16.len("🙂🙂🙂"), "🙂🙂🙂".length);
    assert.equal(Utf16.len("🙂_🙂"), "🙂_🙂".length);
    assert.equal(Utf16.len("foo"), "foo".length);
    assert.equal(Utf16.len("0123456789"), "0123456789".length);
  });
});

describe("TinyStr", () => {
  test("basic", () => {
    assert.deepEqual(TinyStr.hexToRgb("#ffffff"), [255, 255, 255]);
    assert.deepEqual(TinyStr.hexToRgb("#80ff00TruncateMe"), [128, 255, 0]);
  });

  test("truncat", () => {});

  test("invalid arg", () => {
    assert.throws(() => TinyStr.hexToRgb(), /StringExpected/);
    assert.throws(() => TinyStr.hexToRgb(42), /StringExpected/);
    assert.throws(() => TinyStr.hexToRgb([true]), /StringExpected/);
  });
});
