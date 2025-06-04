import assert from "node:assert";
import { createRequire } from "node:module";

import { describe, RUNTIME, test } from "../testing/runner.mjs";
const { AsyncTask, AsyncTaskManaged, AsyncWorker, Promises, ThreadsafeFns } =
  createRequire(import.meta.url)("./test.addon");

describe("promises", () => {
  test("resolve", async () => {
    const result = AsyncWorker.resolvingPromise("is it worth it?");
    assert(result instanceof Promise);
    assert.equal(await result, "?ti htrow ti si");
  });

  test("reject", async () => {
    const result = AsyncWorker.rejectingPromise("is it worth it?");
    assert(result instanceof Promise);

    await assert.rejects(() => result);
    await result.catch(err => {
      assert.deepEqual(err, new Error("daabi da"));
    });
  });
});

describe("thread-safe functions", () => {
  test("stream events to callback", async () => {
    const expectedMsgs = [
      "hey, i just met you",
      "and this is crazy",
      "but, here's my number",
      "so call me, maybe",
    ];

    const { promise, reject, resolve } = Promise.withResolvers();

    let idxMsg = 0;
    ThreadsafeFns.callMeBack(
      /** @param {string} msg */ msg => {
        try {
          assert.equal(msg, expectedMsgs[idxMsg]);
        } catch (error) {
          reject(error);
          return;
        }

        idxMsg += 1;
        if (idxMsg === expectedMsgs.length) {
          resolve();
        }
      },
    );

    await promise;
  });

  test("resolve promise from Zig thread", async () => {
    const result = ThreadsafeFns.makePromise();
    assert(result instanceof Promise);
    assert.equal(await result, "I promise.");
  });
});

describe("promises", () => {
  test("native promise chaining - resolve", async () => {
    const { promise, resolve } = Promise.withResolvers();

    /** @type {string|undefined} */
    var doneResult;

    /** @param {string} res  */
    function onDone(res) {
      doneResult = res;
    }

    const chainedPromise = Promises.chain(promise, onDone);

    resolve(8000);
    assert.equal(await chainedPromise, false);
    assert.equal(doneResult, "done");
  });

  test("native promise chaining - reject", async () => {
    const { promise, reject } = Promise.withResolvers();

    /** @type {string|undefined} */
    var doneResult;

    /** @param {string} res  */
    function onDone(res) {
      doneResult = res;
    }

    const chainedPromise = Promises.chain(promise, onDone);

    reject("something went wrong");
    await assert.rejects(
      () => chainedPromise,
      /\[modified\] something went wrong/,
    );
    assert.equal(doneResult, "done");
  });

  test("native promise chaining - ok only - resolve", async () => {
    const { promise, resolve } = Promise.withResolvers();

    const chainedPromise = Promises.chainOkOnly(promise);

    resolve(9001);
    assert.equal(await chainedPromise, true);
  });

  test("native promise chaining - ok only - reject", async () => {
    const { promise, reject } = Promise.withResolvers();

    const chainedPromise = Promises.chainOkOnly(promise);

    reject("something went wrong");
    await assert.rejects(() => chainedPromise, /something went wrong/);
  });
});

describe("AsyncTask", () => {
  test("with `execute` method only", async () => {
    const result = AsyncTask.scheduleExecuteOnly(3.142);
    assert(result instanceof Promise);
    assert.equal(await result, 3.142);
  });

  test("with `complete` method", async () => {
    const result = AsyncTask.scheduleWithComplete(3.142);
    assert(result instanceof Promise);
    assert.equal(await result, "3.142");
  });

  test("with `cleanup` method", async () => {
    let cleanedUp = false;

    /** @param {boolean} res */
    function onCleanup(res) {
      cleanedUp = res;
    }

    const result = AsyncTask.scheduleWithCleanup(3.142, onCleanup);
    assert(result instanceof Promise);
    assert.equal(await result, 3.142);
    assert(cleanedUp);
  });

  test("with `errConvert` method", async () => {
    let cleanedUp = false;

    /** @param {boolean} res */
    function onCleanup(res) {
      cleanedUp = res;
    }

    const result = AsyncTask.scheduleWithErrConvert(onCleanup);
    assert(result instanceof Promise);
    await assert.rejects(async () => await result, /SorryDave/);

    switch (RUNTIME) {
      case "deno": {
        console.error(
          "🚨 [SKIP] Deno: napi_reject_deferred returns control to JS " +
            "immediately, preventing native async task cleanup.",
        );
        assert(!cleanedUp);
        break;
      }

      default: {
        assert(cleanedUp);
        break;
      }
    }
  });
});

describe("AsyncTaskManaged", () => {
  test("with `execute` method only", async () => {
    const result = AsyncTaskManaged.scheduleExecuteOnly(3.142);
    assert(result instanceof Promise);
    assert.equal(await result, 3.142);
  });

  test("with `complete` method", async () => {
    const result = AsyncTaskManaged.scheduleWithComplete(3.142);
    assert(result instanceof Promise);
    assert.equal(await result, "3.142");
  });

  test("with `cleanup` method", async () => {
    let cleanedUp = false;

    /** @param {boolean} res */
    function onCleanup(res) {
      cleanedUp = res;
    }

    const result = AsyncTaskManaged.scheduleWithCleanup(3.142, onCleanup);
    assert(result instanceof Promise);
    assert.equal(await result, 3.142);
    assert(cleanedUp);
  });

  test("with `errConvert` method", async () => {
    let cleanedUp = false;

    /** @param {boolean} res */
    function onCleanup(res) {
      cleanedUp = res;
    }

    const result = AsyncTaskManaged.scheduleWithErrConvert(onCleanup);
    assert(result instanceof Promise);
    await assert.rejects(async () => await result, /WrongWay/);

    switch (RUNTIME) {
      case "deno": {
        console.error(
          "🚨 [SKIP] Deno: napi_reject_deferred returns control to JS " +
            "immediately, preventing native async task cleanup.",
        );
        assert(!cleanedUp);
        break;
      }

      default: {
        assert(cleanedUp);
        break;
      }
    }
  });
});
