import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, test } from "../../testing/runner.mjs";
import { registerTests } from "../test_cases.mjs";

const addon = createRequire(import.meta.url)("./test.addon");
const { RefsV10 } = addon;

registerTests(addon);

describe("refs - Node-API v10", () => {
  test("supported referenced value types", () => {
    const object = { foo: "bar" };
    assert.strictEqual(RefsV10.createAndExtractRefVal(object), object);

    const string = "foo";
    assert.strictEqual(RefsV10.createAndExtractRefVal(string), string);

    const bigInt = 0xcafe_f00d_50_c001n;
    assert.strictEqual(RefsV10.createAndExtractRefVal(bigInt), bigInt);

    assert.strictEqual(RefsV10.createAndExtractRefVal(42), 42);
    assert.strictEqual(RefsV10.createAndExtractRefVal(true), true);
    assert.strictEqual(RefsV10.createAndExtractRefVal(undefined), undefined);
    assert.strictEqual(RefsV10.createAndExtractRefVal(null), null);

    const arrayBuf = new ArrayBuffer(8);
    assert.strictEqual(RefsV10.createAndExtractRefVal(arrayBuf), arrayBuf);

    const u8Array = new Uint8Array(16);
    assert.strictEqual(RefsV10.createAndExtractRefVal(u8Array), u8Array);

    const dataView = new DataView(u8Array.buffer);
    assert.strictEqual(RefsV10.createAndExtractRefVal(dataView), dataView);

    const symbol = Symbol("sixty");
    assert.strictEqual(RefsV10.createAndExtractRefVal(symbol), symbol);

    const fn = () => "ok";
    assert.strictEqual(RefsV10.createAndExtractRefVal(fn), fn);
  });
});
