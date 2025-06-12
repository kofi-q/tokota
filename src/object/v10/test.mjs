import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../../testing/runner.mjs";
import { registerTests } from "../test_cases.mjs";

const addon = createRequire(import.meta.url)("./test.addon");
const { ObjectsV10 } = addon;

describe("object/v10", () => {
  registerTests(addon);

  describe("objects", () => {
    test("set prop", () => {
      const obj = ObjectsV10.objectWithSetterFns();

      switch (RUNTIME) {
        case "deno": {
          console.error(
            "🚨 [SKIP] Deno: node_api_create_property_key_utf8 not yet supported",
          );
          break;
        }

        default: {
          obj.setWithPropKey("baz", true);
          assert.equal(obj.baz, true);

          break;
        }
      }
    });

    test("get prop", () => {
      const obj = {
        bar: "1986",
        baz: true,
        foo: 42,
      };

      switch (RUNTIME) {
        case "deno": {
          console.error(
            "🚨 [SKIP] Deno: node_api_create_property_key_utf8 not yet supported",
          );
          break;
        }

        default: {
          assert.equal(ObjectsV10.getByPropKey(obj, "baz"), true);
          break;
        }
      }
    });
  });
});
