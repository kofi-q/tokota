import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, test } from "../testing/runner.mjs";
const addon = createRequire(import.meta.url)("./test.addon");

describe("functions", () => {
  test("create - without name", () => {
    /** @type {Function} */
    const fn = addon.fnCreate({ foo: 42 });

    assert.equal(fn.name, "");
    assert.deepEqual(fn(), { foo: 42 });
  });

  test("create - with name", () => {
    /** @type {Function} */
    const fn = addon.fnNamed("foo", { value: "bar" });

    assert.equal(fn.name, "foo");
    assert.deepEqual(fn(), { value: "bar" });
  });

  test("call - single arg", () => {
    /**
     * @param {string} input
     * @this {unknown}
     */
    function reverb(input) {
      assert.strictEqual(this, globalThis);
      return `${input}...${input.substring(0, 2)}...${input.substring(0, 1)}`;
    }

    const result = addon.fnCallSingleArg(reverb, "foo");
    assert.equal(result, "foo...fo...f");
  });

  test("call - multiple arg", () => {
    /**
     * @param {string} a
     * @param {string} b
     * @this {unknown}
     */
    function concat(a, b) {
      assert.strictEqual(this, globalThis);
      return `${a}: ${b}`;
    }

    const result = addon.fnCallMultipleArgs(concat, "foo", "bar");
    assert.equal(result, "foo: bar");
  });

  test("call - with inferred types", () => {
    /**
     * @param {boolean} bool
     * @param {number} num
     * @param {string} str
     * @param {undefined} zigVoid
     * @param {{bar: number; foo: boolean}} struct
     */
    function receive(bool, num, str, zigVoid, struct) {
      assert.equal(bool, true);
      assert.equal(num, 42);
      assert.equal(str, "foo");
      assert.equal(zigVoid, undefined);
      assert.deepEqual(struct, {
        bar: 0xf00d,
        foo: false,
      });
      return "ok";
    }

    const result = addon.fnCallInferredTypes(receive);
    assert.equal(result, "ok");
  });

  test("call - void", () => {
    let called = false;

    function noop() {
      called = true;
    }

    assert.equal(addon.fnCallSingleArg(noop), undefined);
    assert(called);
  });

  test("call - void - optional receiver", () => {
    let called = false;

    function noop() {
      called = true;
    }

    assert.equal(addon.fnCallSingleArgOptional(noop), undefined);
    assert(called);
  });

  test("call - with thisArgs", () => {
    const obj = new (class {
      separator = " | ";

      /**
       * @param {string} a
       * @param {string} b
       * @this {unknown}
       */
      concat(a, b) {
        assert.strictEqual(this, obj);
        return `${a}${this.separator}${b}`;
      }
    })();

    const result = addon.fnCallWithThis(obj, obj.concat, "foo", "bar");
    assert.equal(result, "foo | bar");
  });
});

describe("closures", () => {
  test("binds native data to function", () => {
    const stopTimer = addon.Closures.startTimer();
    assert.equal(typeof stopTimer, "function");

    const elapsedNs = stopTimer();
    assert(elapsedNs > 1n);
  });
});
