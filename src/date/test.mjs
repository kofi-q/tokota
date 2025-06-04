import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, test } from "../testing/runner.mjs";
const api = createRequire(import.meta.url)("./test.addon");

describe("date", () => {
  test("create", () => {
    const date = new Date();
    assert.deepEqual(api.dateFromUnixMillis(date.valueOf()), date);
  });

  test("extract", () => {
    const date = new Date();
    assert.deepEqual(api.dateToUnixMillis(date), date.valueOf());
  });

  test("type check", () => {
    assert.deepEqual(api.isDate(new Date()), true);
    assert.equal(api.isDate(42), false);
    assert.equal(api.isDate("2024-09-20"), false);
  });
});
