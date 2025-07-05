import assert from "node:assert";
import { Buffer } from "node:buffer";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../../testing/runner.mjs";
import { registerTests } from "../test_cases.mjs";

const addon = createRequire(import.meta.url)("./test.addon");
const { BuffersV10 } = addon;

describe("array_buffer/v10", () => {
  registerTests(addon);

  describe("Buffer", () => {
    test("create from ArrayBuffer", () => {
      const arrayBuffer = new ArrayBuffer(8);

      switch (RUNTIME) {
        case "deno": {
          console.error(
            "🚨 [SKIP] Deno: node_api_create_buffer_from_arraybuffer " +
              "not yet supported",
          );

          break;
        }

        default: {
          assert.deepEqual(
            BuffersV10.fromArrayBuffer(arrayBuffer, [0xca, 0xfe, 0xf0, 0x0d]),
            Buffer.from("\xca\xfe\xf0\x0d", "ascii"),
          );

          break;
        }
      }
    });
  });
});
