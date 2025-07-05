import assert from "node:assert";
import { Buffer } from "node:buffer";
import { createRequire } from "node:module";
import process from "node:process";

import { describe, RUNTIME, test } from "./testing/runner.mjs";
const api = createRequire(import.meta.url)("./test.addon");

const { MAX_SAFE_INTEGER, MIN_SAFE_INTEGER } = Number;

test("node version", () => {
  const { major, minor, patch, release } = api.nodeVersion();

  switch (RUNTIME) {
    case "deno":
      console.error(
        "🚨 [SKIP] Deno: napi_get_node_version returns different version " +
          "from `process.version`",
      );
      assert.notEqual(`v${major}.${minor}.${patch}`, process.version);
      break;

    default:
      assert.equal(`v${major}.${minor}.${patch}`, process.version);
      break;
  }

  switch (RUNTIME) {
    case "deno":
      console.error(
        "🚨 [SKIP] Deno: napi_get_node_version returns 'Deno', " +
          "process.release returns 'node'",
      );
      assert.notEqual(release, process.release.name);
      assert.equal(release, "Deno");
      break;

    default:
      assert.equal(release, process.release.name);
      break;
  }
});

test("run script", () => {
  assert.equal(
    api.runScript(`
      let a = 10;
      let b = 32;
      a + b;
    `),
    42,
  );
});

test("module filename", () => {
  /** @type {string} */
  const filename = api.moduleFileName();
  assert(filename.endsWith("test.addon.node"));
});

describe("arg & return-type inference", () => {
  test("string - slice", () => {
    assert.equal(api.returnString(), "foo");
  });

  test("string - slice - non-const", () => {
    assert.equal(api.returnStringNonConst(), "foo");
  });

  test("string - u8 array pointer", () => {
    assert.equal(api.returnStringU8ArrayPtr(), "foo");
  });

  test("string - null-terminated", () => {
    assert.equal(api.returnStringNullTerminated(), "foo");
  });

  test("string - null-terminated - non-const", () => {
    assert.equal(api.returnStringNullTerminatedNonConst(), "foo");
  });

  test("string - null-terminated pointer", () => {
    assert.equal(api.returnStringNullTerminatedPtr(), "foo");
  });

  test("string - null-terminated pointer - non-const", () => {
    assert.equal(api.returnStringNullTerminatedPtrNonConst(), "foo");
  });

  test("string - slice of strings", () => {
    assert.deepEqual(api.returnSliceOfStrings("foo", "bar", "baz"), [
      "foo",
      "bar",
      "baz",
    ]);
  });

  test("string -> tokota.TinyStr -> string", () => {
    assert.equal(api.returnTinyStr("foo"), "foo");
  });

  test("Symbol -> tokota.Symbol -> Symbol", () => {
    const symbol = Symbol("💜");
    assert.strictEqual(api.returnSymbol(symbol), symbol);
  });

  test("Array -> tokota.Array -> Array", () => {
    assert.deepEqual(api.returnTokotaArray(["one", true, 3]), ["one", true, 3]);
    assert.throws(() => api.returnTokotaArray("not an array"), /ArrayExpected/);
  });

  test("[N]T -> Array", () => {
    assert.deepEqual(api.returnZigArray(), [0xcafe, 0xf00d]);
  });

  test("[N]u8 -> Array", () => {
    assert.deepEqual(api.returnZigArrayU8(), [128, 0, 255]);
  });

  test("*[N]T -> Array", () => {
    assert.deepEqual(api.returnZigArrayPtr(), [0xcafe, 0xf00d]);
  });

  test("zig tuple -> Array", () => {
    assert.deepEqual(api.returnZigTuple([42, true]), [42, true]);

    assert.throws(() => api.returnZigTuple("not an array"), /ArrayExpected/);
    assert.throws(
      () => api.returnZigTuple(["not a number", true]),
      /NumberExpected/,
    );
  });

  test("tokota.BigInt -> BigInt", () => {
    assert.equal(
      api.returnBigInt(),
      -0xc001_d00d_0000_0000_cafe_f00d_0000_0000n,
    );
  });

  test("boolean -> bool -> boolean", () => {
    assert.strictEqual(api.returnBool(true), true);
    assert.throws(() => api.returnBool(42), /BooleanExpected/);
    assert.throws(() => api.returnBool("true"), /BooleanExpected/);
    assert.throws(() => api.returnBool(undefined), /BooleanExpected/);
  });

  test("Date -> tokota.Date -> Date", () => {
    const date = new Date();
    date.setFullYear(1996);
    assert.deepEqual(api.returnDate(date), date);

    assert.throws(() => api.returnDate("not a Date"), /DateExpected/);
    assert.throws(() => api.returnDate(1996), /DateExpected/);
  });

  test("zig fn -> function", () => {
    const fnAdd = api.returnZigFn();
    assert.equal(typeof fnAdd, "function");
    assert.equal(fnAdd(5, -2), 3);
  });

  test("function -> tokota.Fn -> function", () => {
    function foo() {
      return "bar";
    }

    assert.strictEqual(api.returnFn(foo), foo);
    assert.equal(api.returnFn(foo)(), "bar");
  });

  test("tokota.Closure -> function (with bound data)", () => {
    const zigFn = api.returnClosure();
    assert(typeof zigFn === "function");
    assert.deepEqual(zigFn(), { foo: 42 });
  });

  test("ArrayBuffer -> tokota.ArrayBuffer -> ArrayBuffer", () => {
    const buffer = Uint8Array.of(0xca, 0xfe, 0xf0, 0x0d).buffer;
    assert.strictEqual(api.returnArrayBuffer(buffer), buffer);

    assert.throws(
      () => api.returnArrayBuffer("not an ArrayBuffer"),
      /ArrayBufferExpected/,
    );

    assert.throws(() => api.returnArrayBuffer({}), /ArrayBufferExpected/);

    const u8Array = Uint8Array.of(0xfa, 0xce);
    assert.throws(() => api.returnArrayBuffer(u8Array), /ArrayBufferExpected/);
    assert.throws(
      () => api.returnArrayBuffer(new DataView(u8Array.buffer)),
      /ArrayBufferExpected/,
    );
  });

  test("Buffer -> tokota.Buffer -> Buffer", () => {
    const buffer = Buffer.of(0xca, 0xfe, 0xf0, 0x0d);
    assert.strictEqual(api.returnBuffer(buffer), buffer);

    assert.throws(() => api.returnBuffer("not a Buffer"), /BufferExpected/);
  });

  test("DataView -> tokota.DataView -> DataView", () => {
    const buffer = Uint8Array.of(0xca, 0xfe, 0xf0, 0x0d).buffer;
    const dataView = new DataView(buffer);
    assert.strictEqual(api.returnDataView(dataView), dataView);

    assert.throws(
      () => api.returnDataView("not a DataView"),
      /DataViewExpected/,
    );
  });

  test("TypedArray -> tokota.TypedArray -> TypedArray", () => {
    const array = Uint32Array.of(0xcafef00d, 0xc001bead);
    assert.strictEqual(api.returnTypedArray(array), array);

    assert.throws(
      () => api.returnTypedArray("not a Uint32Array"),
      /Uint32ArrayExpected/,
    );
  });

  /**
   * @param {number} actual
   * @param {number} expected
   */
  function assertFloatsAreClose(actual, expected) {
    // `Number.EPSILON` is too small for the f32 case, for some reason.
    const FLOAT_TOLERANCE = 0.001;

    assert(
      Math.abs(expected - actual) < FLOAT_TOLERANCE,
      `
      Expected: ${expected} ± ${FLOAT_TOLERANCE}
      Actual: ${actual}
    `,
    );
  }

  test("comptime_float -> number", () => {
    assert.equal(api.returnFloatComptime(), 3.142);
  });

  test("number -> f32 -> number", () => {
    assertFloatsAreClose(api.returnFloatF32(3.142), 3.142);
    assert.throws(() => api.returnFloatF32("3.142"), /NumberExpected/);
  });

  test("number -> f64 -> number", () => {
    assert.equal(api.returnFloatF64(3.142), 3.142);
    assert.throws(() => api.returnFloatF64("3.142"), /NumberExpected/);
    assert.equal(api.returnFloatF64(Number.MAX_VALUE), Number.MAX_VALUE);
    assert.equal(api.returnFloatF64(Number.MIN_VALUE), Number.MIN_VALUE);
  });

  test("comptime_int -> number", () => {
    assert.equal(api.returnIntComptimeMaxSafe(), MAX_SAFE_INTEGER);
    assert.equal(api.returnIntComptimeMinSafe(), MIN_SAFE_INTEGER);
  });

  test("number -> signed int -> number", () => {
    assert.equal(api.returnIntI8(-0x80), -0x80);
    assert.equal(api.returnIntI8(0x7f), 0x7f);

    assert.throws(() => api.returnIntI8("-42"), /NumberExpected/);
    assert.throws(() => api.returnIntI8(-0x81), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI8(0x80), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI8(0.5), /IntegerExpected/);

    assert.equal(api.returnIntI16(-0x8000), -0x8000);
    assert.equal(api.returnIntI16(0x7fff), 0x7fff);

    assert.throws(() => api.returnIntI16("-42"), /NumberExpected/);
    assert.throws(() => api.returnIntI16(-0x8001), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI16(0x8000), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI16(0.5), /IntegerExpected/);

    assert.equal(api.returnIntI32(-0x80000000), -0x80000000);
    assert.equal(api.returnIntI32(0x7fffffff), 0x7fffffff);

    assert.throws(() => api.returnIntI32("-42"), /NumberExpected/);
    assert.throws(() => api.returnIntI32(-0x80000001), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI32(0x80000000), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI32(0.5), /IntegerExpected/);

    assert.equal(api.returnIntI53(api.I53_MIN), api.I53_MIN);
    assert.equal(api.returnIntI53(api.I53_MAX), api.I53_MAX);

    assert.throws(() => api.returnIntI53("-42"), /NumberExpected/);
    assert.throws(() => api.returnIntI53(api.I53_MIN - 1), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI53(api.I53_MAX + 1), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntI53(0.5), /IntegerExpected/);

    assert.equal(api.returnIntI54(MIN_SAFE_INTEGER), MIN_SAFE_INTEGER);
    assert.equal(api.returnIntI54(MAX_SAFE_INTEGER), MAX_SAFE_INTEGER);

    assert.throws(() => api.returnIntI54("-42"), /NumberExpected/);
    assert.throws(
      () => api.returnIntI54(MIN_SAFE_INTEGER - 1),
      /IntegerOutOfRange/,
    );
    assert.throws(
      () => api.returnIntI54(MAX_SAFE_INTEGER + 1),
      /IntegerOutOfRange/,
    );
    assert.throws(() => api.returnIntI54(0.5), /IntegerExpected/);

    assert.equal(api.returnIntI54FromF64(MIN_SAFE_INTEGER), MIN_SAFE_INTEGER);
    assert.equal(api.returnIntI54FromF64(MAX_SAFE_INTEGER), MAX_SAFE_INTEGER);
    assert.throws(
      () => api.returnIntI54FromF64(MIN_SAFE_INTEGER - 1),
      /IntegerOutOfRange/,
    );

    assert.equal(api.returnIntI64(-42n), -42n);
    assert.throws(() => api.returnIntI64("-42n"), /BigIntExpected/);

    assert.equal(api.returnIntI128(-42n), -42n);
    assert.equal(api.returnIntI128(api.I128_MAX), api.I128_MAX);
    assert.equal(api.returnIntI128(api.I128_MIN), api.I128_MIN);
    assert.throws(() => api.returnIntI128("-42n"), /BigIntExpected/);
    assert.throws(() => api.returnIntI128(api.I128_MAX + 1n), /BigIntOverflow/);
    assert.throws(() => api.returnIntI128(api.I128_MIN - 1n), /BigIntOverflow/);
  });

  test("number -> unsigned int -> number", () => {
    assert.equal(api.returnIntU8(0), 0);
    assert.equal(api.returnIntU8(0xff), 0xff);

    assert.throws(() => api.returnIntU8("42"), /NumberExpected/);
    assert.throws(() => api.returnIntU8(-1), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntU8(0x100), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntU8(0.5), /IntegerExpected/);

    assert.equal(api.returnIntU16(0), 0);
    assert.equal(api.returnIntU16(0xffff), 0xffff);

    assert.throws(() => api.returnIntU16("42"), /NumberExpected/);
    assert.throws(() => api.returnIntU16(-1), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntU16(0x10000), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntU16(0.5), /IntegerExpected/);

    assert.equal(api.returnIntU32(0), 0);
    assert.equal(api.returnIntU32(0xffffffff), 0xffffffff);

    assert.throws(() => api.returnIntU32("42"), /NumberExpected/);
    assert.throws(() => api.returnIntU32(-1), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntU32(0x100000000), /IntegerOutOfRange/);
    assert.throws(() => api.returnIntU32(0.5), /IntegerExpected/);

    assert.equal(api.returnIntU53(0), 0);
    assert.equal(api.returnIntU53(MAX_SAFE_INTEGER), MAX_SAFE_INTEGER);

    assert.throws(() => api.returnIntU53("42"), /NumberExpected/);
    assert.throws(() => api.returnIntU53(-1), /IntegerOutOfRange/);
    assert.throws(
      () => api.returnIntU53(MAX_SAFE_INTEGER + 1),
      /IntegerOutOfRange/,
    );
    assert.throws(() => api.returnIntU53(0.5), /IntegerExpected/);

    assert.equal(api.returnIntU64(42n), 42n);
    assert.throws(() => api.returnIntU64("42n"), /BigIntExpected/);

    assert.equal(api.returnIntU128(42n), 42n);
    assert.equal(api.returnIntU128(api.U128_MAX), api.U128_MAX);
    assert.throws(() => api.returnIntU128("42n"), /BigIntExpected/);
    assert.throws(() => api.returnIntU128(-1n), /ExpectedUnsignedBigInt/);

    switch (RUNTIME) {
      case "bun": {
        console.error(
          "🚨 [SKIP] Bun: napi_get_value_bigint_words - incorrect word count " +
            "returned when buffer length specified.",
        );

        assert.doesNotThrow(
          () => api.returnIntU128(api.U128_MAX + 1n),
          /BigIntOverflow/,
        );

        break;
      }

      case "deno": {
        console.error(
          "🚨 [SKIP] Deno: napi_get_value_bigint_words - incorrect word count " +
            "returned when buffer length specified.",
        );

        assert.doesNotThrow(
          () => api.returnIntU128(api.U128_MAX + 1n),
          /BigIntOverflow/,
        );

        break;
      }

      default: {
        assert.throws(
          () => api.returnIntU128(api.U128_MAX + 1n),
          /BigIntOverflow/,
        );

        break;
      }
    }
  });

  test("object -> tokota.Object -> object", () => {
    assert.deepEqual(api.returnObject({ agoo: "amɛɛ" }), { agoo: "amɛɛ" });

    assert.deepEqual(api.returnObject(["also", "kinda", "object-ish"]), [
      "also",
      "kinda",
      "object-ish",
    ]);

    assert.strictEqual(api.returnObjectOptional(), undefined);

    assert.throws(() => api.returnObject("not an object"), /ObjectExpected/);
  });

  test("Promise -> tokota.Promise -> Promise", async () => {
    const promise = Promise.resolve("hi");
    assert.equal(await api.returnPromise(promise), "hi");

    assert.throws(() => api.returnPromise("not a promise"), /PromiseExpected/);
  });

  test("void -> undefined", () => {
    assert.equal(api.returnVoid(), undefined);
  });

  test("struct type -> interface object", () => {
    const PuppyShelter = api.returnStructType();

    assert.equal(PuppyShelter.capacity, 42);
    assert.equal(PuppyShelter.adopt("Spot"), "Spot");

    assert.equal(PuppyShelter.unexportedConst, undefined);
    assert.equal(PuppyShelter.unexportedFn, undefined);

    assert.equal(api.returnStructTypeOptional(), undefined);
  });

  test("tokota.Api -> interface object with bound method data", () => {
    const PuppyShelter = api.returnTokotaApi("foo bar");

    assert.equal(PuppyShelter.capacity, 42);
    assert.equal(PuppyShelter.adopt("Spot"), "Spot");
    assert.equal(PuppyShelter.hasAttachedData(), true);
    assert.equal(PuppyShelter.attachedData(), "foo bar");

    assert.equal(PuppyShelter.unexportedConst, undefined);
    assert.equal(PuppyShelter.unexportedFn, undefined);

    assert.equal(api.returnTokotaApiOptional(), undefined);
  });

  test("struct instance -> object with copied fields", () => {
    const Condition = {
      cloudy: 0,
      sunny: 1,
      windy: 2,
    };

    assert.deepEqual(
      api.returnStructInstance({
        airQuality: 52,
        condition: Condition.sunny,
        forecast: "Cloudy conditions expected around 12:00",
        humidity: 0.5,
        rainExpected: false,
        tempC: 27,
      }),
      {
        airQuality: 52,
        condition: Condition.sunny,
        forecast: "Cloudy conditions expected around 12:00",
        humidity: 0.5,
        rainExpected: false,
        tempC: 27,
      },
    );

    assert.deepEqual(
      api.returnStructInstance({
        condition: Condition.sunny,
        forecast: "Cloudy conditions expected around 12:00",
        humidity: 0.5,
        rainExpected: false,
        tempC: 27,
      }),
      {
        airQuality: undefined,
        condition: Condition.sunny,
        forecast: "Cloudy conditions expected around 12:00",
        humidity: 0.5,
        rainExpected: false,
        tempC: 27,
      },
    );

    assert.throws(
      () =>
        api.returnStructInstance({
          condition: Condition.sunny,
          forecast: "Cloudy conditions expected around 12:00",
          humidity: "not a number",
          rainExpected: false,
          tempC: 27,
        }),
      /NumberExpected/,
    );

    assert.throws(
      () => api.returnStructInstance("not an object"),
      /ObjectExpected/,
    );
  });

  test("enum -> enum constants object", () => {
    const LogLevel = api.returnEnumType();
    assert.deepEqual(LogLevel, {
      catastrophic: 2,
      err: 1,
      warn: 0,
    });

    assert.strictEqual(
      api.returnEnumValue(LogLevel.catastrophic),
      LogLevel.catastrophic,
    );

    assert.strictEqual(
      api.returnEnumValueOptional(LogLevel.catastrophic),
      LogLevel.catastrophic,
    );

    assert.strictEqual(api.returnEnumValueOptional(), undefined);

    assert.throws(() => api.returnEnumValue(5), /InvalidEnumTag/);
    assert.throws(() => api.returnEnumValue(0xffff), /InvalidEnumTag/);
  });

  test("string -> t.enums.StringEnum -> string", () => {
    assert.strictEqual(api.returnStringEnumValue("warn"), "warn");

    assert.strictEqual(
      api.returnStringEnumValueOptional("catastrophic"),
      "catastrophic",
    );

    assert.strictEqual(api.returnStringEnumValueOptional(), undefined);

    assert.throws(() => api.returnStringEnumValue(5), /StringExpected/);
    assert.throws(() => api.returnStringEnumValue("nope"), /InvalidEnumTag/);
  });

  test("string -> t.enums.StringEnumImpl -> string", () => {
    assert.strictEqual(api.returnStringEnumImplValue("DO"), "DO");
    assert.strictEqual(api.returnStringEnumImplValue("RE"), "RE");
    assert.strictEqual(api.returnStringEnumImplValue("MI"), "MI");

    assert.throws(() => api.returnStringEnumImplValue(5), /StringExpected/);
    assert.throws(() => api.returnStringEnumImplValue("PO"), /InvalidEnumTag/);
  });

  test("packed struct type -> object with copied fields", () => {
    const AbilityFlags = api.returnBitFlagsAsEnum();
    assert.deepEqual(AbilityFlags, {
      bugless_code: 1 << 0,
      comedic_timing: 1 << 1,
      flight: 1 << 2,
      invisibility: 1 << 3,
      lactose_tolerance: 1 << 4,
      nonchalance: 1 << 5,
      powerless: 0,
      super_strength: 1 << 6,
      telepathy: 1 << 13,
    });
  });

  test("packed struct instance -> number", () => {
    const AbilityFlags = api.returnBitFlagsAsEnum();
    assert.deepEqual(AbilityFlags, {
      bugless_code: 1 << 0,
      comedic_timing: 1 << 1,
      flight: 1 << 2,
      invisibility: 1 << 3,
      lactose_tolerance: 1 << 4,
      nonchalance: 1 << 5,
      powerless: 0,
      super_strength: 1 << 6,
      telepathy: 1 << 13,
    });

    assert.equal(
      api.returnPackedStructInstance(
        AbilityFlags.flight | AbilityFlags.nonchalance,
      ),
      AbilityFlags.flight | AbilityFlags.nonchalance,
    );

    assert.equal(
      api.returnPackedStructInstanceOptional(
        AbilityFlags.flight | AbilityFlags.nonchalance,
      ),
      AbilityFlags.flight | AbilityFlags.nonchalance,
    );

    assert.equal(api.returnPackedStructInstance(0), AbilityFlags.powerless);

    assert.equal(api.returnPackedStructInstanceOptional(), undefined);

    assert.throws(() => api.returnPackedStructInstance(-1), /InvalidFlagValue/);
    assert.throws(
      () => api.returnPackedStructInstance(1 << 16),
      /InvalidFlagValue/,
    );
  });
});
