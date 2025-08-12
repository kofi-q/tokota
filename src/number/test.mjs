import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../testing/runner.mjs";
const { BigInts, Floats, Ints } = createRequire(import.meta.url)(
  "./test.addon",
);

describe("ints", () => {
  test("get i32", () => {
    assert.equal(Ints.i32Min(), -0x80_00_00_00);
  });

  test("get u32", () => {
    assert.equal(Ints.u32Max(), 0xff_ff_ff_ff);
  });

  test("roundtrip i32", () => {
    assert.equal(Ints.roundtripI32(-0x11_22_33_44), -0x11_22_33_44);
  });

  test("roundtrip u32", () => {
    assert.equal(Ints.roundtripU32(0x11_22_33_44), 0x11_22_33_44);
  });

  test("roundtrip int safe limits", () => {
    assert.equal(
      Ints.roundtripIntSafeMinMax(Number.MIN_SAFE_INTEGER),
      Number.MIN_SAFE_INTEGER,
    );
    assert.equal(
      Ints.roundtripIntSafeMinMax(Number.MAX_SAFE_INTEGER),
      Number.MAX_SAFE_INTEGER,
    );
  });

  test("coerce string", () => {
    assert.equal(Ints.coerce("-123456789"), -123456789);
  });
});

describe("floats", () => {
  test("roundtrip f64", () => {
    assert.equal(Floats.roundtripF64(1.23456789), 1.23456789);
    assert.equal(Floats.roundtripF64(-1.23456789), -1.23456789);

    assert.equal(Floats.roundtripF64(Number.MAX_VALUE), Number.MAX_VALUE);
    assert.equal(Floats.roundtripF64(Number.MIN_VALUE), Number.MIN_VALUE);
  });

  test("coerce string", () => {
    assert.equal(Floats.coerce("-1.23456789"), -1.23456789);
  });
});

describe("bigInts", () => {
  test("get i64 min", () => {
    assert.equal(BigInts.i64Min(), -0x80000000_00000000n);
  });

  test("get u64 max", () => {
    assert.equal(BigInts.u64Max(), 0xffffffff_ffffffffn);
  });

  test("get words", () => {
    assert.equal(BigInts.twoWordMin(), -0xffffffff_ffffffff_ffffffff_ffffffffn);
    assert.equal(BigInts.twoWordMax(), 0xffffffff_ffffffff_ffffffff_ffffffffn);
  });

  test("roundtrip i64 - lossless", () => {
    assert.deepEqual(BigInts.roundtripI64(-0x11_22_33_44_55_66_77_88n), {
      lossless: true,
      val: -0x11_22_33_44_55_66_77_88n,
    });

    assert.deepEqual(BigInts.roundtripI64(-0n), {
      lossless: true,
      val: -0n,
    });
  });

  test("roundtrip i64 - lossy", () => {
    assert.deepEqual(BigInts.roundtripI64(-0x11_22_33_44_55_66_77_88_99n), {
      lossless: false,
      val: -0x22_33_44_55_66_77_88_99n,
    });
  });

  test("roundtrip u64 - lossless", () => {
    assert.deepEqual(BigInts.roundtripU64(0x11_22_33_44_55_66_77_88n), {
      lossless: true,
      val: 0x11_22_33_44_55_66_77_88n,
    });

    assert.deepEqual(BigInts.roundtripU64(0n), {
      lossless: true,
      val: 0n,
    });
  });

  test("roundtrip u64 - lossy", () => {
    assert.deepEqual(BigInts.roundtripU64(0x11_22_33_44_55_66_77_88_99n), {
      lossless: false,
      val: 0x22_33_44_55_66_77_88_99n,
    });
  });

  test("roundtrip words - const - unsigned", () => {
    assert.equal(BigInts.roundtripWordsU128(0n), 0n);
    assert.equal(BigInts.roundtripWordsU128(1n), 1n);

    assert.equal(
      BigInts.roundtripWordsU128(
        0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
      ),
      0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
    );

    assert.equal(
      BigInts.roundtripWordsU128(0xffffffff_ffffffff_ffffffff_ffffffffn),
      0xffffffff_ffffffff_ffffffff_ffffffffn,
    );

    assert.throws(
      () =>
        BigInts.roundtripWordsU128(
          -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
        ),
      /ExpectedUnsignedBigInt/,
    );

    switch (RUNTIME) {
      case "deno": {
        console.error(
          "🚨 [SKIP] Deno: napi_get_value_bigint_words - incorrect word count " +
            "returned when buffer length specified.",
        );

        assert.doesNotThrow(
          () =>
            BigInts.roundtripWordsU128(
              0x1_00000000_00000000_00000000_00000000n,
            ),
          /BigIntOverflow/,
        );

        break;
      }

      default: {
        assert.throws(
          () =>
            BigInts.roundtripWordsU128(
              0x1_00000000_00000000_00000000_00000000n,
            ),
          /BigIntOverflow/,
        );

        break;
      }
    }
  });

  test("roundtrip words - const - unsigned - non-word-aligned", () => {
    assert.equal(BigInts.roundtripWordsU155(0n), 0n);
    assert.equal(BigInts.roundtripWordsU155(1n), 1n);

    assert.equal(
      BigInts.roundtripWordsU155(
        0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
      ),
      0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
    );

    assert.equal(
      BigInts.roundtripWordsU155(BigInts.U155_MAX),
      BigInts.U155_MAX,
    );

    assert.throws(
      () =>
        BigInts.roundtripWordsU155(
          -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
        ),
      /ExpectedUnsignedBigInt/,
    );

    assert.throws(
      () => BigInts.roundtripWordsU155(BigInts.U155_MAX + 1n),
      /BigIntOverflow/,
    );
  });

  test("roundtrip words - const - signed", () => {
    assert.equal(BigInts.roundtripWordsI128(0n), 0n);
    assert.equal(BigInts.roundtripWordsI128(1n), 1n);

    assert.equal(
      BigInts.roundtripWordsI128(
        -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
      ),
      -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
    );

    assert.equal(
      BigInts.roundtripWordsI128(-0x80000000_00000000_00000000_00000000n),
      -0x80000000_00000000_00000000_00000000n,
    );

    assert.equal(
      BigInts.roundtripWordsI128(0x7fffffff_ffffffff_ffffffff_ffffffffn),
      0x7fffffff_ffffffff_ffffffff_ffffffffn,
    );

    assert.throws(
      () => BigInts.roundtripWordsI128(-0x80000000_00000000_00000000_00000001n),
      /BigIntOverflow/,
    );

    assert.throws(
      () => BigInts.roundtripWordsI128(0x80000000_00000000_00000000_00000000n),
      /BigIntOverflow/,
    );

    assert.throws(
      () => BigInts.roundtripWordsI128(-0x80000000_00000000_00000000_00000001n),
      /BigIntOverflow/,
    );
  });

  test("roundtrip words - const - signed - non-word-aligned", () => {
    assert.equal(BigInts.roundtripWordsI155(0n), 0n);
    assert.equal(BigInts.roundtripWordsI155(1n), 1n);

    assert.equal(
      BigInts.roundtripWordsI155(
        -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
      ),
      -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
    );

    assert.equal(
      BigInts.roundtripWordsI155(BigInts.I155_MAX),
      BigInts.I155_MAX,
    );

    assert.equal(
      BigInts.roundtripWordsI155(BigInts.I155_MIN),
      BigInts.I155_MIN,
    );

    assert.throws(
      () => BigInts.roundtripWordsI155(BigInts.I155_MAX + 1n),
      /BigIntOverflow/,
    );

    assert.throws(
      () => BigInts.roundtripWordsI155(BigInts.I155_MIN - 1n),
      /BigIntOverflow/,
    );
  });

  test("roundtrip words - with buffer", () => {
    assert.equal(BigInts.roundtripWordsBuf(0n), 0n);
    assert.equal(BigInts.roundtripWordsBuf(1n), 1n);

    assert.equal(
      BigInts.roundtripWordsBuf(
        0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
      ),
      0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
    );
    assert.equal(
      BigInts.roundtripWordsBuf(
        -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
      ),
      -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00n,
    );

    switch (RUNTIME) {
      case "deno": {
        console.error(
          "🚨 [SKIP] Deno: napi_get_value_bigint_words - incorrect word count " +
            "returned when buffer length specified.",
        );

        assert.doesNotThrow(
          () =>
            BigInts.roundtripWordsBuf(
              0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00_11n,
            ),
          /BigIntOverflow/,
        );
        assert.doesNotThrow(
          () =>
            BigInts.roundtripWordsBuf(
              -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00_11n,
            ),
          /BigIntOverflow/,
        );

        break;
      }

      default: {
        assert.throws(
          () =>
            BigInts.roundtripWordsBuf(
              0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00_11n,
            ),
          /BigIntOverflow/,
        );
        assert.throws(
          () =>
            BigInts.roundtripWordsBuf(
              -0x11_22_33_44_55_66_77_88_99_aa_bb_cc_dd_ee_ff_00_11n,
            ),
          /BigIntOverflow/,
        );
        break;
      }
    }
  });
});
