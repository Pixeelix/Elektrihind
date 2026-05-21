import pg from "pg";
import { config, requireDatabaseUrl } from "./config.js";

const { Pool } = pg;

export const pool = new Pool({
  connectionString: requireDatabaseUrl(),
  ssl: config.databaseSsl ? { rejectUnauthorized: false } : undefined,
});

export async function closePool(): Promise<void> {
  await pool.end();
}
