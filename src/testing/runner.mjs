import assert from "node:assert";
import path from "node:path";

const argOne = process.argv[0];
assert(typeof argOne === "string");

const RUNTIME = path.basename(argOne, path.extname(argOne));

let runnerPath = "";
switch (RUNTIME) {
  case "bun":
    runnerPath = "./runner.bun.mjs";
    break;

  case "deno":
    runnerPath = "./runner.deno.mjs";
    break;

  case "node":
    runnerPath = "./runner.node.mjs";
    break;

  default:
    throw new Error(`Unexpected runtime: ${RUNTIME}`);
}

const { afterAll, afterEach, beforeAll, beforeEach, describe, test } =
  await import(runnerPath);

export { afterAll, afterEach, beforeAll, beforeEach, describe, RUNTIME, test };
