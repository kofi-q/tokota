import assert from "node:assert";
import { EventEmitter } from "node:events";

import { describe, test } from "../testing/runner.mjs";

/**
 * @param {*} addon
 */
export function registerTests(addon) {
  const { Classes, Objects, RetroEncabulator, TurboEncabulator } = addon;
  describe("classes", () => {
    test("ES-instantiated native classes", () => {
      assert.equal(TurboEncabulator.NAME, "TurboEncabulator");
      assert.equal(TurboEncabulator.manufacturer(), "General Electric");

      const turbo = new TurboEncabulator(0.4);
      assert(turbo instanceof TurboEncabulator);
      assert(turbo.fumbleGuardEnabled());
      assert.equal(turbo.magnetoReluctance(), 0);

      turbo.fumbleGuardToggle();
      assert(!turbo.fumbleGuardEnabled());

      turbo.magnetoReluctanceSet(0.9);
      assert.equal(turbo.magnetoReluctance(), 0.9);

      const methodThisUndefined = turbo.magnetoReluctance;
      assert.throws(() => methodThisUndefined());

      const retro = new RetroEncabulator();
      const methodThisInvalid = turbo.magnetoReluctance.bind(retro);
      assert.throws(() => methodThisInvalid());

      assert(Classes.isTurboEncabulator(turbo));
      assert(!Classes.isTurboEncabulator(retro));

      assert.equal(retro.capacitiveDuractanceGet(), 0.55);

      retro.capacitiveDuractanceSet(1.0);
      assert.equal(retro.capacitiveDuractanceGet(), 1.0);
    });

    test("Native-instantiated ES classes", () => {
      const url = Classes.create(URL, ["foo/bar", "https://example.com"]);
      assert.deepEqual(url, new URL("foo/bar", "https://example.com"));
    });
  });

  describe("objects", () => {
    test("with values", () => {
      assert.deepEqual(Objects.objectWithValues("foo", 42), { foo: 42 });
      assert.deepEqual(Objects.objectWithValues("foo", "bar"), { foo: "bar" });
      assert.deepEqual(Objects.objectWithValues("5", true), { 5: true });
    });

    test("set prop", () => {
      const obj = Objects.objectWithSetterFns();

      obj.setWithStringKey("foo", 42);
      assert.equal(obj.foo, 42);

      obj.setWithValKey("bar", "1986");
      assert.equal(obj.bar, "1986");
    });

    test("methods with native data", () => {
      const obj = Objects.objectWithData("foo", "bar");
      assert.equal(obj.extractDataA(obj), "foo");
      assert.equal(obj.extractDataB(obj), "bar");
    });

    test("get prop", () => {
      const obj = {
        bar: "1986",
        baz: true,
        foo: 42,
      };

      assert.equal(Objects.getByStringKey(obj, "foo"), 42);
      assert.equal(Objects.getByValKey(obj, "bar"), "1986");
    });

    test("has [own] prop", () => {
      const obj = { baz: true, foo: 42 };
      assert(Objects.hasStringKey(obj, "foo"));
      assert(Objects.hasOwnStringKey(obj, "foo"));

      assert(Objects.hasValKey(obj, "baz"));
      assert(Objects.hasOwnValKey(obj, "baz"));

      assert(Objects.hasStringKey(obj, "toString"));
      assert(!Objects.hasOwnStringKey(obj, "toString"));

      assert(Objects.hasValKey(obj, "toString"));
      assert(!Objects.hasOwnValKey(obj, "toString"));
    });

    test("delete prop", () => {
      const obj = { baz: true, foo: 42 };

      Objects.deleteByStringKey(obj, "foo");
      assert.deepEqual(obj, { baz: true });

      assert(Objects.deleteByValKey(obj, "baz"));
      assert.deepEqual(obj, {});
    });

    test("keys vs keys extended", () => {
      const obj = { bar: "ayekoo", baz: true, foo: 42 };

      /** @type {string[]} */
      const keys = Objects.getKeys(obj);
      assert.deepEqual(keys, ["bar", "baz", "foo"]);

      /** @type {string[]} */
      const keysExtended = Objects.getKeysExtended(obj);

      assert.notDeepEqual(keysExtended, keys);
      assert(keysExtended.includes("bar"));
      assert(keysExtended.includes("baz"));
      assert(keysExtended.includes("foo"));
    });

    test("freeze", () => {
      const obj = { baz: true, foo: 42 };

      Objects.freezeObj(obj);
      assert.throws(() => {
        obj.foo = 24;
      });
    });

    test("seal", () => {
      const obj = { baz: true, foo: 42 };
      Objects.sealObj(obj);

      obj.baz = false;
      assert.deepEqual(obj, { baz: false, foo: 42 });

      assert.throws(() => {
        Object.defineProperty(obj, "bar", { value: "one" });
      });
    });

    test("finalizer", () => {
      const obj = { baz: true, foo: 42 };
      Objects.addFinalizer(obj);
    });

    test("remove wrap", () => {
      const obj = Objects.withRemovableWrap();
      assert(obj.isWrapped());

      obj.removeWrap();
      obj.removeWrap(); // Test idempotence.
      assert(!obj.isWrapped());
    });

    test("type tags", () => {
      const taggedObj = Objects.taggedObject();
      assert(Objects.isTaggedObject(taggedObj));

      const objCopy = { ...taggedObj };
      assert(!Objects.isTaggedObject(objCopy));
    });

    test("prototype", () => {
      const eventEmitter = new EventEmitter();
      assert.equal(Objects.prototypeOf(eventEmitter), EventEmitter.prototype);
    });
  });
}
