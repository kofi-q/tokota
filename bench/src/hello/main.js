const fs = require("node:fs");
const mitata = require("mitata");

const c = require("./addon.c.node");
const cpp = require("./addon.cpp.node");
const zig_ffi = require("./addon.zig.ffi.node");
const zig = require("./addon.zig.node");

mitata.summary(() => {
  mitata.bench("c", c.hello);
  mitata.bench("cpp (node-addon-api)", cpp.hello);
  mitata.bench("zig (tokota ffi)", zig_ffi.hello);
  mitata.bench("zig (tokota)", zig.hello);
});

mitata
  .run({
    colors: true,
  })
  .then(async () => {
    const stats = [
      ["c", "addon.c.node"],
      ["cpp (node-addon-api)", "addon.cpp.node"],
      ["zig (tokota ffi)", "addon.zig.ffi.node"],
      ["zig (tokota)", "addon.zig.node"],
    ];

    const size_key = "Size (KB)";

    for (const file_info of stats) {
      const stat = fs.statSync(`${__dirname}/${file_info[1]}`);
      file_info[1] = { [size_key]: stat.size / 1024 };
    }

    stats.sort((a, b) => a[1][size_key] - b[1][size_key]);

    console.log();
    console.log("Binary sizes");
    console.log("------------");
    console.table(Object.fromEntries(stats));
  });
