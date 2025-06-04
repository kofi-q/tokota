import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, test } from "../testing/runner.mjs";
const api = createRequire(import.meta.url)("./test.addon");

describe("errors", () => {
  test("create generic error", () => {
    const err = api.genericErr("foo", "ERR_FOO");
    assertError(Error, err, { code: "ERR_FOO", message: "foo" });
  });

  test("create generic error - from Zig error code", () => {
    const err = api.errFromZigErrCode();
    assertError(Error, err, { code: "MadeUpError", message: "foo" });
  });

  test("create range error", () => {
    const err = api.rangeErr("foo", "ERR_FOO");
    assertError(RangeError, err, { code: "ERR_FOO", message: "foo" });
  });

  test("create syntax error", () => {
    const err = api.syntaxErr("foo", "ERR_FOO");
    assertError(SyntaxError, err, { code: "ERR_FOO", message: "foo" });
  });

  test("create type error", () => {
    const err = api.typeErr("foo", "ERR_FOO");
    assertError(TypeError, err, { code: "ERR_FOO", message: "foo" });
  });

  test("is error", () => {
    assert(api.isError(new Error("foo")));
    assert(!api.isError("bar"));
  });

  test("'catch' last exception", () => {
    const err = new Error("foo", { cause: "42" });

    const err_roundtrip = api.callFailingFunction(() => {
      throw new Error("foo", { cause: "42" });
    });

    assert.deepEqual(err_roundtrip, err);
  });

  test("throw existing error", () => {
    const err = new Error("foo", { cause: "42" });
    assert.throws(() => api.throwExistingErr(err), err);
  });

  test("throw value as error", () => {
    assert.throws(() => api.throwExistingErr("foo"), /foo/);
  });

  test("throw generic error", () => {
    try {
      api.throwGenericErr("foo", "ERR_FOO");
    } catch (err) {
      assertError(Error, err, { code: "ERR_FOO", message: "foo" });
      return;
    }

    assert.fail("expected error");
  });

  test("throw range error", () => {
    try {
      api.throwRangeErr("foo", "ERR_FOO");
    } catch (err) {
      assertError(RangeError, err, { code: "ERR_FOO", message: "foo" });
      return;
    }

    assert.fail("expected error");
  });

  test("throw syntax error", () => {
    try {
      api.throwSyntaxErr("foo", "ERR_FOO");
    } catch (err) {
      assertError(SyntaxError, err, { code: "ERR_FOO", message: "foo" });
      return;
    }

    assert.fail("expected error");
  });

  test("throw type error", () => {
    try {
      api.throwTypeErr("foo", "ERR_FOO");
    } catch (err) {
      assertError(TypeError, err, { code: "ERR_FOO", message: "foo" });
      return;
    }

    assert.fail("expected error");
  });
});

/**  @typedef {{ code: string; message: string; }} AddonError */

/**
 * @param {Function} ErrType
 * @param {any} actual
 * @param {{ code: string; message: string; }} expected
 */
function assertError(ErrType, actual, expected) {
  assert(actual instanceof ErrType);
  assert("code" in actual);
  assert("message" in actual);
  assert.deepEqual(
    {
      code: actual.code,
      message: actual.message,
    },
    expected,
  );
}
