import assert from "node:assert";
import { Buffer } from "node:buffer";

import { describe, test } from "../testing/runner.mjs";

/**
 * @param {*} addon
 */
export function registerTests(addon) {
  const { ArrayBuffers, Buffers, DataViews, TypedArrays } = addon;

  describe("ArrayBuffer", () => {
    test("create - js-owned", () => {
      /** @type {ArrayBuffer} */
      const buffer = ArrayBuffers.create(Uint8Array.of(0xca, 0xfe, 0xf0, 0x0d));
      assert.equal(new DataView(buffer).getUint32(0, false), 0xcafef00d);
    });

    test("create - zig-owned", () => {
      /** @type {ArrayBuffer} */
      const buffer = ArrayBuffers.createZigOwned();

      const dataView = new DataView(buffer);
      assert.equal(dataView.getUint32(0, false), 0xcafef00d);

      dataView.setUint16(0, 0xface, false);
      ArrayBuffers.assertZigOwned(
        buffer,
        Uint8Array.of(0xfa, 0xce, 0xf0, 0x0d),
      );
    });

    test("detach", () => {
      const arrayBuffer = new ArrayBuffer(16);
      assert(!arrayBuffer.detached);

      ArrayBuffers.detach(arrayBuffer);
      assert(arrayBuffer.detached);
    });

    test("check detached", () => {
      const arrayBuffer = new ArrayBuffer(16);
      arrayBuffer.transfer();
      ArrayBuffers.assertDetached(arrayBuffer);
    });

    test("isArrayBuffer", () => {
      const isArrayBuffer = ArrayBuffers.isArrayBuffer;

      const u8Array = Uint8Array.of(0xca, 0xfe);
      assert.equal(isArrayBuffer(u8Array.buffer), true);

      assert.equal(isArrayBuffer(u8Array), false);
      assert.equal(isArrayBuffer(new DataView(u8Array.buffer)), false);
      assert.equal(isArrayBuffer("nope"), false);
      assert.equal(isArrayBuffer(1996), false);
      assert.equal(isArrayBuffer([0xca, 0xfe]), false);
    });
  });

  describe("TypedArray", () => {
    describe("native-generated", () => {
      test("Int8Array", () => {
        const i8Array = TypedArrays.generateI8();
        assert(i8Array instanceof Int8Array);
        assert.equal(i8Array.buffer.byteLength, 8);
        assert.deepEqual([...i8Array.values()], [-0x0a, 0x0b, -0x0c, 0x0d]);
      });

      test("Int8Array - with Env.typedArrayFrom()", () => {
        const i8Array = TypedArrays.generateI8Copy();
        assert(i8Array instanceof Int8Array);
        assert.equal(i8Array.buffer.byteLength, 4);
        assert.deepEqual([...i8Array.values()], [-0x0a, 0x0b, -0x0c, 0x0d]);
      });

      test("Uint8Array", () => {
        const u8Array = TypedArrays.generateU8();
        assert(u8Array instanceof Uint8Array);
        assert.equal(u8Array.buffer.byteLength, 8);
        assert.deepEqual([...u8Array.values()], [0xca, 0xfe, 0xf0, 0x0d]);
      });

      test("Uint8Array - with Env.typedArrayFrom()", () => {
        const u8Array = TypedArrays.generateU8Copy();
        assert(u8Array instanceof Uint8Array);
        assert.equal(u8Array.buffer.byteLength, 4);
        assert.deepEqual([...u8Array.values()], [0xca, 0xfe, 0xf0, 0x0d]);
      });

      test("Uint8ClampedArray", () => {
        const u8ClampedArray = TypedArrays.generateU8Clamped();
        assert(u8ClampedArray instanceof Uint8ClampedArray);
        assert.equal(u8ClampedArray.buffer.byteLength, 8);
        assert.deepEqual(
          [...u8ClampedArray.values()],
          [0xca, 0xfe, 0xf0, 0x0d],
        );
      });

      test("Int16Array", () => {
        const i16Array = TypedArrays.generateI16();
        assert(i16Array instanceof Int16Array);
        assert.equal(i16Array.buffer.byteLength, 16);
        assert.deepEqual(
          [...i16Array.values()],
          [-0x0abc, 0x0def, -0x0123, 0x0456],
        );
      });

      test("Int16Array - with Env.typedArrayFrom()", () => {
        const i16Array = TypedArrays.generateI16Copy();
        assert(i16Array instanceof Int16Array);
        assert.equal(i16Array.buffer.byteLength, 8);
        assert.deepEqual(
          [...i16Array.values()],
          [-0x0abc, 0x0def, -0x0123, 0x0456],
        );
      });

      test("Uint16Array", () => {
        const u16Array = TypedArrays.generateU16();
        assert(u16Array instanceof Uint16Array);
        assert.equal(u16Array.buffer.byteLength, 16);
        assert.deepEqual(
          [...u16Array.values()],
          [0xcafe, 0xf00d, 0xc001, 0xface],
        );
      });

      test("Uint16Array - with Env.typedArrayFrom()", () => {
        const u16Array = TypedArrays.generateU16Copy();
        assert(u16Array instanceof Uint16Array);
        assert.equal(u16Array.buffer.byteLength, 8);
        assert.deepEqual(
          [...u16Array.values()],
          [0xcafe, 0xf00d, 0xc001, 0xface],
        );
      });

      test("Int32Array", () => {
        const i32Array = TypedArrays.generateI32();
        assert(i32Array instanceof Int32Array);
        assert.equal(i32Array.buffer.byteLength, 32);
        assert.deepEqual([...i32Array.values()], [-0x0abc0def, 0x01230456]);
      });

      test("Int32Array - with Env.typedArrayFrom()", () => {
        const i32Array = TypedArrays.generateI32Copy();
        assert(i32Array instanceof Int32Array);
        assert.equal(i32Array.buffer.byteLength, 8);
        assert.deepEqual([...i32Array.values()], [-0x0abc0def, 0x01230456]);
      });

      test("Uint32Array", () => {
        const u32Array = TypedArrays.generateU32();
        assert(u32Array instanceof Uint32Array);
        assert.equal(u32Array.buffer.byteLength, 32);
        assert.deepEqual([...u32Array.values()], [0xcafef00d, 0xc001face]);
      });

      test("Uint32Array - with Env.typedArrayFrom()", () => {
        const u32Array = TypedArrays.generateU32Copy();
        assert(u32Array instanceof Uint32Array);
        assert.equal(u32Array.buffer.byteLength, 8);
        assert.deepEqual([...u32Array.values()], [0xcafef00d, 0xc001face]);
      });

      test("BigInt64Array", () => {
        const bigI64Array = TypedArrays.generateBigI64();
        assert(bigI64Array instanceof BigInt64Array);
        assert.equal(bigI64Array.buffer.byteLength, 64);
        assert.deepEqual(
          [...bigI64Array.values()],
          [-0x0abc0def01230456n, 0x012304560abc0defn],
        );
      });

      test("BigInt64Array - with Env.typedArrayFrom()", () => {
        const bigI64Array = TypedArrays.generateBigI64Copy();
        assert(bigI64Array instanceof BigInt64Array);
        assert.equal(bigI64Array.buffer.byteLength, 16);
        assert.deepEqual(
          [...bigI64Array.values()],
          [-0x0abc0def01230456n, 0x012304560abc0defn],
        );
      });

      test("BigUint64Array", () => {
        const bigU64Array = TypedArrays.generateBigU64();
        assert(bigU64Array instanceof BigUint64Array);
        assert.equal(bigU64Array.buffer.byteLength, 64);
        assert.deepEqual(
          [...bigU64Array.values()],
          [0xcafef00dc001facen, 0xdadad00dfeedceden],
        );
      });

      test("BigUint64Array - with Env.typedArrayFrom()", () => {
        const bigU64Array = TypedArrays.generateBigU64Copy();
        assert(bigU64Array instanceof BigUint64Array);
        assert.equal(bigU64Array.buffer.byteLength, 16);
        assert.deepEqual(
          [...bigU64Array.values()],
          [0xcafef00dc001facen, 0xdadad00dfeedceden],
        );
      });

      /**
       * @param {number[]} actual
       * @param {number[]} expected
       */
      function assertFloatsEqualish(actual, expected) {
        assert.equal(
          actual.length,
          expected.length,
          "Mismatched float array lengths",
        );

        for (let i = 0; i < actual.length; i += 1) {
          const expectedItem = expected[i];
          assert(expectedItem);

          const actualItem = actual[i];
          assert(actualItem);

          const diff = Math.abs(expectedItem - actualItem);
          assert(
            diff <= 0.00000001,
            `[Index ${i}] Expected ${expectedItem}, got ${actualItem}`,
          );
        }
      }

      test("Float32Array", () => {
        const f32Array = TypedArrays.generateF32();
        assert(f32Array instanceof Float32Array);
        assert.equal(f32Array.buffer.byteLength, 32);
        assertFloatsEqualish([...f32Array.values()], [-1.23456789, 1.23456789]);
      });

      test("Float32Array - with Env.typedArrayFrom()", () => {
        const f32Array = TypedArrays.generateF32Copy();
        assert(f32Array instanceof Float32Array);
        assert.equal(f32Array.buffer.byteLength, 8);
        assertFloatsEqualish([...f32Array.values()], [-1.23456789, 1.23456789]);
      });

      test("Float64Array", () => {
        const f64Array = TypedArrays.generateF64();
        assert(f64Array instanceof Float64Array);
        assert.equal(f64Array.buffer.byteLength, 64);
        assertFloatsEqualish([...f64Array.values()], [-1.23456789, 1.23456789]);
      });

      test("Float64Array - with Env.typedArrayFrom()", () => {
        const f64Array = TypedArrays.generateF64Copy();
        assert(f64Array instanceof Float64Array);
        assert.equal(f64Array.buffer.byteLength, 16);
        assertFloatsEqualish([...f64Array.values()], [-1.23456789, 1.23456789]);
      });
    });

    test("from ArrayBuffer", () => {
      const arrayBuffer = Buffer.from(
        "HTTP/1.1 200 Ok" + "\r\n\r\n" + "\xca\xfe\xf0\x0d" + "\r\n",
        "ascii",
      ).buffer;

      const bodyBytes = TypedArrays.getHttpBody(arrayBuffer);
      assert(bodyBytes instanceof Uint8Array);
      assert.deepEqual([...bodyBytes.values()], [0xca, 0xfe, 0xf0, 0x0d]);
    });

    test("to ArrayBuffer", () => {
      const arrayBuffer = new ArrayBuffer(10);
      new Uint8Array(arrayBuffer).set([
        0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9,
      ]);

      const u16Array = new Uint16Array(arrayBuffer, 4, 2);
      assert.equal(TypedArrays.backingArrayBuffer(u16Array), arrayBuffer);
    });
  });

  describe("DataView", () => {
    test("native-generated", () => {
      const dataView = DataViews.generate();
      assert(dataView instanceof DataView);
      assert.equal(dataView.byteLength, 10);
      assert.equal(dataView.buffer.byteLength, 20);
      assert.equal(dataView.getUint32(2, false), 0x02030405);
    });

    test("from ArrayBuffer", () => {
      const arrayBuffer = Buffer.from(
        "HTTP/1.1 200 Ok" + "\r\n\r\n" + "\xca\xfe\xf0\x0d" + "\r\n",
        "ascii",
      ).buffer;

      const bodyDataView = DataViews.getHttpBody(arrayBuffer);
      assert(bodyDataView instanceof DataView);
      assert.equal(bodyDataView.getUint32(0, false), 0xcafef00d);
    });

    test("to ArrayBuffer", () => {
      const arrayBuffer = Uint8Array.from([
        0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9,
      ]).buffer;

      const dataView = new DataView(arrayBuffer, 4, 2);
      assert.equal(DataViews.backingArrayBuffer(dataView), arrayBuffer);
    });
  });

  describe("Buffer", () => {
    test("receive", () => {
      const buffer = Buffer.from("\xca\xfe\xf0\x0d", "ascii");
      Buffers.assertBuffer(buffer);
    });

    test("create - js-owned", () => {
      /**
       *  @type {import("node:buffer").Buffer}
       */
      const buffer = Buffers.create(Uint8Array.of(0xca, 0xfe, 0xf0, 0x0d));
      assert.equal(buffer.readUint32BE(), 0xcafef00d);
    });

    test("create - zig-owned", () => {
      /**
       *  @type {import("node:buffer").Buffer}
       */
      const buffer = Buffers.createZigOwned(
        Uint8Array.of(0xca, 0xfe, 0xf0, 0x0d),
      );
      assert.equal(buffer.readUint32BE(), 0xcafef00d);

      buffer.writeUint16BE(0xface);
      Buffers.assertZigOwned(buffer, Uint8Array.of(0xfa, 0xce, 0xf0, 0x0d));
    });

    test("create from copy", () => {
      assert.deepEqual(
        Buffers.fromCopy(),
        Buffer.from("\xca\xfe\xf0\x0d", "ascii"),
      );
    });
  });
}
