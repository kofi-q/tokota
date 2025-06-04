import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, test } from "../testing/runner.mjs";
const api = createRequire(import.meta.url)("./test.addon");

describe("arrays", () => {
  test("create and set", () => {
    assert.deepEqual(api.arrayCreateAndSet(), []);
    assert.equal(api.arrayCreateAndSet().length, 0);
    assert.deepEqual(api.arrayCreateAndSet("one", true, 3), ["one", true, 3]);
  });

  test("create with length", () => {
    assert.equal(api.arrayCreateWithLength(3).length, 3);
    for (const elem of api.arrayCreateWithLength(3)) {
      assert.equal(elem, undefined);
    }
  });

  test("arrayFrom - Zig array (single-type)", () => {
    assert.deepEqual(
      api.arrayFromZigArray(1983, 1986, 1989),
      [1983, 1986, 1989],
    );
  });

  test("arrayFrom - Zig array (mixed-type)", () => {
    assert.deepEqual(api.arrayFromZigArrayMixed(42, true, { foo: "bar" }), [
      42,
      true,
      { foo: "bar" },
    ]);
  });

  test("arrayFrom - Zig tuple", () => {
    assert.deepEqual(api.arrayFromTuple(42, true, "ayekoo"), [
      42,
      true,
      "ayekoo",
    ]);
  });

  test("arrayFrom - Zig slice (single-type)", () => {
    assert.deepEqual(api.arrayFromSlice(1983, 1986, 1989), [1983, 1986, 1989]);
  });

  test("arrayFrom - Zig slice (mixed-type)", () => {
    assert.deepEqual(api.arrayFromSliceMixed(42, true, { foo: "bar" }), [
      42,
      true,
      { foo: "bar" },
    ]);
  });

  test("get element", () => {
    assert.equal(api.arrayGet([3, true, "one"], 2), "one");
    assert.equal(api.arrayGet([3, true, "one"], 0), 3);
    assert.equal(api.arrayGet([3, true, "one"], 5), undefined);
  });

  test("get element - as Zig type", () => {
    assert.equal(api.arrayGetAsNativeStr([3, true, "one"], 2), "one");
    assert.throws(
      () => api.arrayGetAsNativeStr([3, true, "one"], 0),
      /StringExpected/,
    );
    assert.throws(
      () => api.arrayGetAsNativeStr([3, true, "one"], 5),
      /StringExpected/,
    );
  });

  test("get element - as Zig optional", () => {
    assert.equal(api.arrayGetAsNativeStrOpt([3, true, "one"], 2), "one");
    assert.throws(
      () => api.arrayGetAsNativeStrOpt([3, true, "one"], 0),
      /StringExpected/,
    );
    assert.equal(api.arrayGetAsNativeStrOpt([3, true, "one"], 5), undefined);
  });

  test("delete element", () => {
    const array = ["foo", "bar", "baz"];
    api.arrayDelete(array, 1);

    const expected = ["foo", "bar", "baz"];
    delete expected[1];

    assert.deepEqual(array, expected);

    assert.equal(api.arrayDelete(array, 10), true);
    assert.deepEqual(array, expected);
  });

  test("existence checks", () => {
    const array = new Array(3);
    array[1] = "foo";

    assert.equal(api.arrayIsSet(array, 1), true);
    assert.equal(api.arrayIsSet(array, 2), false);
    assert.equal(api.arrayIsSet(array, 10), false);
  });

  test("length checks", () => {
    assert.equal(api.arrayLength([]), 0);
    assert.equal(api.arrayLength(["one", true]), 2);
    assert.equal(api.arrayLength(new Array(3)), 3);
  });

  test("type checks", () => {
    assert.equal(api.isArray([]), true);
    assert.equal(api.isArray([1, "2", "🌳"]), true);
    assert.equal(api.isArray({ foo: "bar" }), false);
    assert.equal(api.isArray({ length: 5 }), false);
    assert.equal(api.isArray("agoo"), false);
  });
});
