import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { pool, query } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";
import { z } from "zod";

const upsertSchema = z.object({
  contacts: z
    .array(
      z.object({
        phoneE164: z.string().regex(/^\+[1-9]\d{6,14}$/),
        displayName: z.string().max(160).optional().default(""),
      }),
    )
    .max(2000),
});

function authUserId(req: Request): string | null {
  const token = bearerFromAuthHeader(req.headers.get("authorization"));
  if (!token) return null;
  try {
    return verifyAccessToken(token).sub;
  } catch {
    return null;
  }
}

export async function GET(req: Request) {
  const userId = authUserId(req);
  if (!userId) return jsonError("Unauthorized", 401);

  const res = await query(
    `SELECT id, phone_e164, display_name, created_at
     FROM contacts WHERE user_id = $1 ORDER BY display_name ASC`,
    [userId],
  );
  return jsonOk({ contacts: res.rows });
}

export async function PUT(req: Request) {
  const userId = authUserId(req);
  if (!userId) return jsonError("Unauthorized", 401);

  try {
    const body = upsertSchema.parse(await req.json());
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      for (const c of body.contacts) {
        await client.query(
          `INSERT INTO contacts (user_id, phone_e164, display_name)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id, phone_e164)
           DO UPDATE SET display_name = EXCLUDED.display_name`,
          [userId, c.phoneE164, c.displayName ?? ""],
        );
      }
      await client.query("COMMIT");
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
    return jsonOk({ synced: body.contacts.length });
  } catch (e) {
    console.error(e);
    return jsonError("Invalid contacts payload", 400);
  }
}
