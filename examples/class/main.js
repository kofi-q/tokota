const addon = require("./addon.node");
const LightSwitch = addon.LightSwitch;

const lightSwitch = new LightSwitch(true);
console.log("Class instance created:", lightSwitch);
console.log("  Initial state:", lightSwitch.isOn());

lightSwitch.toggle();
console.log("  State after toggle:", lightSwitch.isOn());
