import path from "node:path";
import assert from "node:assert";

const argOne = process.argv[0];
assert(typeof argOne === "string");

const basename = path.basename(argOne);
const RUNTIME = basename.substring(-path.extname(basename).length);

let runnerPath = "";
switch (RUNTIME) {
  case "node":
    runnerPath = "./runner.node.mjs";
    break;

  case "bun":
    runnerPath = "./runner.bun.mjs";
    break;

  case "deno":
    runnerPath = "./runner.deno.mjs";
    break;

  default:
    throw new Error(`Unexpected runtime: ${RUNTIME}`);
}

const { afterAll, afterEach, beforeAll, beforeEach, describe, test } =
  await import(runnerPath);

export { afterAll, afterEach, beforeAll, beforeEach, describe, RUNTIME, test };
