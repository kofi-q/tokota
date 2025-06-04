const addon = require("./addon.node");

addon.setTodoColor("#fefefe");
addon.setTodoColor([128, 128, 0]);

console.log();
console.log("Setting to-do color with invalid value...");
console.log();
console.log("⬇ ⬇  Expected Error ⬇ ⬇");
console.log();
try {
  // @ts-expect-error ts(2345)
  addon.setTodoColor(42);
} catch (err) {
  console.error(err);
}
