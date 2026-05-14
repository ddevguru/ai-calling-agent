/* eslint-disable @typescript-eslint/no-require-imports */
const fs = require("fs");
const path = require("path");
const { Client } = require("pg");
require("dotenv").config({ path: ".env.local" });
require("dotenv").config();

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error(
      "ensure-schema: DATABASE_URL is not set. Add it in Render (e.g. Neon free tier) then redeploy.",
    );
    process.exit(1);
  }

  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    const check = await client.query(
      `SELECT 1 FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name = 'users' LIMIT 1`,
    );
    if (check.rows.length > 0) {
      console.log("ensure-schema: tables already exist, skipping.");
      return;
    }

    const sqlPath = path.join(__dirname, "..", "sql", "schema.sql");
    const sql = fs.readFileSync(sqlPath, "utf8");
    await client.query(sql);
    console.log("ensure-schema: applied sql/schema.sql");
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error("ensure-schema failed:", err);
  process.exit(1);
});
