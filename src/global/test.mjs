import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../testing/runner.mjs";
const { Symbols } = createRequire(import.meta.url)("./test.addon");

describe("symbols", () => {
  test("global", () => {
    const existingSymbol = Symbol.for("foo");
    assert.strictEqual(Symbols.forKey("foo"), existingSymbol);
    assert.strictEqual(Symbols.forKey("bar"), Symbol.for("bar"));
    assert.strictEqual(Symbols.forKey(""), Symbol.for(""));
  });

  test("local - from JS value", () => {
    const existingSymbol = Symbol("foo");
    assert.notEqual(Symbols.new("foo"), existingSymbol);
    assert.equal(Symbols.new("foo").toString(), existingSymbol.toString());

    // Non-string Symbols currently only seem to be supported in Deno.
    switch (RUNTIME) {
      case "bun": {
        console.error(
          "🚨 [SKIP] Bun: napi_create_symbol errors on non-string values",
        );

        assert.throws(() => Symbols.new(0xcafe));
        assert.throws(() => Symbols.new({ foo: "bar" }));

        break;
      }

      case "node": {
        console.error(
          "🚨 [SKIP] Node: napi_create_symbol errors on non-string values",
        );

        assert.throws(() => Symbols.new(0xcafe));
        assert.throws(() => Symbols.new({ foo: "bar" }));

        break;
      }

      default: {
        assert.equal(Symbols.new(0xcafe).toString(), Symbol(0xcafe).toString());
        assert.equal(
          Symbols.new({ foo: "bar" }).toString(),
          // @ts-ignore
          Symbol({ foo: "bar" }).toString(),
        );

        break;
      }
    }
  });

  test("local - from native value", () => {
    assert.equal(Symbols.newFromNative().toString(), Symbol("✅").toString());
  });
});
