const addon = require("./addon.node");

const userId = 2;
const timeoutSecs = 1;

console.log(`Streaming to-dos for user ${userId} for ${timeoutSecs}s...`);

/** @type {Timer | undefined} */
let timer = undefined;
const cancel = addon.todoStream(userId, (err, todo) => {
  if (err?.code === "Done") {
    console.log("Received end-of-stream signal");
    clearTimeout(timer);
    return;
  }

  if (err) {
    console.error("[Stream Err]", err);
    return;
  }

  const icon = todo.completed ? "✅" : "⬜️";
  console.log(`${icon} [User ${todo.user_id}] #${todo.id}: ${todo.title}`);
});

timer = setTimeout(cancel, timeoutSecs * 1000);
