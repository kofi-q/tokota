const addon = require("./addon.node");

async function main() {
  console.log(`\nFetching to-do totals...`);

  const { completed, pending } = await addon.todoTotals();
  console.log(`    ✅ Total completed: ${completed}`);
  console.log(`    ⬜️ Total pending:   ${pending}`);

  const userId1 = 2;
  const userId2 = 4;
  const limit = 10;

  const deferredTodos = Promise.all([
    addon.todosForUser(userId1, limit),
    addon.todosForUser(userId2, limit),
  ]);

  console.log(
    `\nFetching first ${limit} to-dos for users ${userId1} and ${userId2}...`,
  );

  const todoLists = await deferredTodos.catch(error => {
    console.error(`Error fetching to-do's:`, error);
    process.exit(1);
  });

  for (const todoList of todoLists) {
    console.log();
    for (const todo of todoList) {
      const icon = todo.completed ? "✅" : "⬜️";
      console.log(`${icon} [User ${todo.user_id}] #${todo.id}: ${todo.title}`);
    }
  }
}

void main().catch(err => {
  console.error(err);
});
