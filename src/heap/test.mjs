import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../testing/runner.mjs";
const { Externals, InstanceData, Mem, removeFailingCleanupHooks } =
  createRequire(import.meta.url)("./test.addon");

test("cleanup hooks", () => {
  removeFailingCleanupHooks();
});

test("instanceData", () => {
  assert.deepEqual(InstanceData.get(), { num: undefined, str: undefined });

  InstanceData.set();
  assert.deepEqual(InstanceData.get(), {
    num: 1996,
    str: "instance data",
  });
});

test("external (native) values", () => {
  const external = Externals.create();
  const otherExternal = Externals.createOther();

  assert(typeof external === "object");
  assert(typeof otherExternal === "object");

  Externals.check(external);
  assert.throws(() => Externals.check(otherExternal), /NativeObjectExpected/);
});

describe("native memory", () => {
  test("adjust", async () => {
    const initial = Mem.adjust(0);
    assert.equal(Mem.adjust(2 * 1024), initial + 2 * 1024);

    switch (RUNTIME) {
      case "bun": {
        console.error(
          "🚨 [SKIP] Bun: napi_adjust_external_memory with a negative delta " +
            "doesn't seem to reduce the registered memory.",
        );

        assert.equal(Mem.adjust(-1024), initial + 2 * 1024);
        assert.equal(Mem.adjust(-1024), initial + 2 * 1024);
        break;
      }

      default: {
        assert.equal(Mem.adjust(-1024), initial + 1024);
        assert.equal(Mem.adjust(-1024), initial);
        break;
      }
    }
  });
});
