import { closePool } from "./db.js";
import { runPriceCheck } from "./notifications.js";

try {
  const summary = await runPriceCheck();
  console.log(JSON.stringify(summary, null, 2));
  await closePool();
  process.exit(summary.failed === 0 ? 0 : 1);
} catch (error) {
  console.error(error);
  await closePool();
  process.exit(1);
}
