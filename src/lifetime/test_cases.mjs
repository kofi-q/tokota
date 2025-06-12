import assert from "node:assert";
import process from "node:process";

import { describe, RUNTIME, test } from "../testing/runner.mjs";

/**
 * @param {*} addon
 */
export function registerTests(addon) {
  const { HandleScopes, Refs } = addon;

  describe("handle scopes", () => {
    switch (RUNTIME) {
      case "deno":
        console.error(
          "🚨 [SKIP] Deno: napi_open_handle_scope returns null pointer",
        );
        return;

      default:
        break;
    }

    test("regular", () => {
      const fnMemoryUsage = process.memoryUsage;
      const memUsageStart = fnMemoryUsage();

      const { memUsageEnd, sum } = HandleScopes.sumWithHandleScopes(
        () => Math.random() * 10,
        fnMemoryUsage,
      );
      assert(sum > 1_000_000);

      // [2025-02-24] RSS Measurements - 1M loops:
      // ====================================================
      // | Runtime        | Without scopes | With scopes    |
      // ====================================================
      // | Bun v1.2.2     | ~1.6x increase | ~2.0x increase |
      // | Deno v2.2.2    | ~1.3x increase | NOT SUPPORTED  |
      // | NodeJS v23.7.0 | ~1.8x increase | ~1.2x increase |
      // ----------------------------------------------------
      const rssIncreaseRatio = memUsageEnd.rss / memUsageStart.rss;
      const rssThreshold = RUNTIME === "bun" ? 2.1 : 1.5;
      assert(
        rssIncreaseRatio < rssThreshold,
        `\nExpected RSS increase < ${rssThreshold.toPrecision(3)}x` +
          `\nWas ${rssIncreaseRatio.toPrecision(3)}x`,
      );

      // [2025-02-24] Heap Usage Measurements - 1M loops:
      // ====================================================
      // | Runtime        | Without scopes | With scopes    |
      // ====================================================
      // | Bun v1.2.2     | No increase    | No increase    |
      // | Deno v2.2.2    | ~1.3x increase | NOT SUPPORTED  |
      // | NodeJS v23.7.0 | ~4.6x increase | ~1.2x increase |
      // ----------------------------------------------------
      const heapUsageIncreaseRatio =
        memUsageEnd.heapUsed / memUsageStart.heapUsed;
      assert(
        heapUsageIncreaseRatio < 1.5,
        `\nExpected heap usage increase < 1.5x` +
          `\nWas ${heapUsageIncreaseRatio.toPrecision(3)}x`,
      );
    });

    test("escapable", () => {
      const fnMemoryUsage = process.memoryUsage;
      const memUsageStart = fnMemoryUsage();

      const { memUsageEnd, sum } = HandleScopes.sumWithEscapableHandleScopes(
        () => Math.random() * 10,
        fnMemoryUsage,
      );
      assert(sum > 1_000_000);

      // See above for last set of measurements.
      const rssIncreaseRatio = memUsageEnd.rss / memUsageStart.rss;
      const rssThreshold = RUNTIME === "bun" ? 2.1 : 1.5;
      assert(
        rssIncreaseRatio < rssThreshold,
        `\nExpected RSS increase < ${rssThreshold.toPrecision(3)}x` +
          `\nWas ${rssIncreaseRatio.toPrecision(3)}x`,
      );

      // See above for last set of measurements.
      const heapUsageIncreaseRatio =
        memUsageEnd.heapUsed / memUsageStart.heapUsed;
      assert(
        heapUsageIncreaseRatio < 1.5,
        `\nExpected heap usage increase < 1.5x` +
          `\nWas ${heapUsageIncreaseRatio.toPrecision(3)}x`,
      );
    });
  });

  describe("refs", () => {
    test("short-lived reference", async () => {
      /** @type {any[]} */
      const array = [];

      let refCount = Refs.tempRefCreate(array);
      refCount = Refs.tempRefIncrementCount();
      assert.equal(refCount, 2);
      assert.deepEqual(array, []);

      refCount = Refs.tempRefIncrementCount();
      assert.equal(refCount, 3);
      assert.deepEqual(array, []);

      Refs.tempRefSetElement(0, "foo");
      assert.deepEqual(array, ["foo"]);

      refCount = Refs.tempRefDecrementCount();
      assert.equal(refCount, 2);
      assert.deepEqual(array, ["foo"]);

      Refs.tempRefSetElement(1, "bar");
      assert.deepEqual(array, ["foo", "bar"]);
      assert.deepEqual(Refs.tempRefGetValue(), ["foo", "bar"]);

      refCount = Refs.tempRefDecrementCount();
      assert.equal(refCount, 1);

      refCount = Refs.tempRefDecrementCount();
      assert.equal(refCount, 0);

      switch (RUNTIME) {
        case "bun":
          // [NOTE] Not necessarily a bad thing, just different from the NodeJS
          // reference implementation.
          console.error(
            "🚨 [SKIP] Bun: napi_reference_unref doesn't return an error " +
              "when the ref count is already 0.",
          );
          refCount = Refs.tempRefDecrementCount();
          assert.equal(refCount, 0);
          break;

        default:
          assert.throws(Refs.tempRefDecrementCount);
          break;
      }

      Refs.tempRefDelete();
      assert.deepEqual(array, ["foo", "bar"]);
    });

    test("supported referenced value types", () => {
      const object = { foo: "bar" };
      assert.strictEqual(Refs.createAndExtractRefObject(object), object);

      const symbol = Symbol("💜");
      assert.strictEqual(Refs.createAndExtractRefSymbol(symbol), symbol);

      const array = [1, "two"];
      assert.strictEqual(Refs.createAndExtractRefArray(array), array);

      const arrayBuf = new ArrayBuffer(8);
      assert.strictEqual(
        Refs.createAndExtractRefArrayBuffer(arrayBuf),
        arrayBuf,
      );

      const u8Array = new Uint8Array(16);
      assert.strictEqual(Refs.createAndExtractRefTypedArray(u8Array), u8Array);

      const dataView = new DataView(u8Array.buffer);
      assert.strictEqual(Refs.createAndExtractRefDataView(dataView), dataView);

      const fn = () => "ok";
      assert.strictEqual(Refs.createAndExtractRefFn(fn), fn);

      const promise = Promise.resolve();
      assert.strictEqual(Refs.createAndExtractRefPromise(promise), promise);
    });
  });
}
