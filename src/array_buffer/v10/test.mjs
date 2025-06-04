import assert from "node:assert";
import { Buffer } from "node:buffer";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../../testing/runner.mjs";
import { registerTests } from "../test_cases.mjs";

const addon = createRequire(import.meta.url)("./test.addon");
const { BuffersV10 } = addon;

registerTests(addon);

describe("Buffer", () => {
  test("create from ArrayBuffer", () => {
    const arrayBuffer = new ArrayBuffer(8);

    switch (RUNTIME) {
      case "bun": {
        console.error(
          "🚨 [SKIP] Bun: node_api_create_buffer_from_arraybuffer creates a " +
            "Buffer with different backing data the original ArrayBuffer",
        );

        assert.deepEqual(
          BuffersV10.fromArrayBuffer(arrayBuffer, [0xca, 0xfe, 0xf0, 0x0d]),
          // Should break when this gets fixed:
          Buffer.of(0x0, 0x0, 0x0, 0x0),
        );

        break;
      }

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
