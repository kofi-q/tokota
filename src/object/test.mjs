import { createRequire } from "node:module";

import { registerTests } from "./test_cases.mjs";

registerTests(createRequire(import.meta.url)("./test.addon"));
