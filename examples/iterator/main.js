const addon = require("./addon.node");

const userId = 2;

console.log(`Iterating over to-dos for user ${userId}...`);

for (const todo of addon.todoIterator(userId)) {
  const icon = todo.completed ? "✅" : "⬜️";
  console.log(`${icon} [User ${todo.user_id}] #${todo.id}: ${todo.title}`);
}
