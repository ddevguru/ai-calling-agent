import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { pool, query } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";
import { z } from "zod";

const profileSchema = z.object({
  name: z.string().min(1).max(80),
  instructions: z.string().max(8000).optional(),
  voiceId: z.string().max(64).optional(),
  language: z.string().min(2).max(16).optional(),
  isDefault: z.boolean().optional(),
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
    `SELECT id, name, instructions, voice_id, language, is_default, created_at
     FROM ai_profiles WHERE user_id = $1 ORDER BY created_at ASC`,
    [userId],
  );
  return jsonOk({ profiles: res.rows });
}

export async function POST(req: Request) {
  const userId = authUserId(req);
  if (!userId) return jsonError("Unauthorized", 401);

  try {
    const body = profileSchema.parse(await req.json());
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      if (body.isDefault) {
        await client.query(
          `UPDATE ai_profiles SET is_default = false WHERE user_id = $1`,
          [userId],
        );
      }
      const ins = await client.query(
        `INSERT INTO ai_profiles (user_id, name, instructions, voice_id, language, is_default)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, name, instructions, voice_id, language, is_default, created_at`,
        [
          userId,
          body.name,
          body.instructions ??
            "You answer phone calls politely and concisely on behalf of the user.",
          body.voiceId ?? "alloy",
          body.language ?? "en",
          body.isDefault ?? false,
        ],
      );
      await client.query("COMMIT");
      return jsonOk({ profile: ins.rows[0] }, 201);
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  } catch (e) {
    console.error(e);
    return jsonError("Could not create profile", 400);
  }
}
