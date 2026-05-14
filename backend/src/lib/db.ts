import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30_000,
});

export type DbClient = import("pg").PoolClient;

export async function query<T extends import("pg").QueryResultRow = import("pg").QueryResultRow>(
  text: string,
  params?: unknown[],
): Promise<{ rows: T[] }> {
  const res = await pool.query<T>(text, params);
  return { rows: res.rows };
}

export { pool };
