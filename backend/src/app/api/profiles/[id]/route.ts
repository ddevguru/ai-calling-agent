import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { pool } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";
import { z } from "zod";

const patchSchema = z.object({
  name: z.string().min(1).max(80).optional(),
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

type Ctx = { params: Promise<{ id: string }> };

export async function PATCH(req: Request, ctx: Ctx) {
  const userId = authUserId(req);
  if (!userId) return jsonError("Unauthorized", 401);
  const { id } = await ctx.params;

  try {
    const body = patchSchema.parse(await req.json());
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      if (body.isDefault) {
        await client.query(
          `UPDATE ai_profiles SET is_default = false WHERE user_id = $1`,
          [userId],
        );
      }
      const res = await client.query(
        `UPDATE ai_profiles
         SET
           name = COALESCE($1, name),
           instructions = COALESCE($2, instructions),
           voice_id = COALESCE($3, voice_id),
           language = COALESCE($4, language),
           is_default = COALESCE($5, is_default)
         WHERE id = $6 AND user_id = $7
         RETURNING id, name, instructions, voice_id, language, is_default, updated_at`,
        [
          body.name ?? null,
          body.instructions ?? null,
          body.voiceId ?? null,
          body.language ?? null,
          body.isDefault ?? null,
          id,
          userId,
        ],
      );
      if (!res.rows[0]) {
        await client.query("ROLLBACK");
        return jsonError("Profile not found", 404);
      }
      await client.query("COMMIT");
      return jsonOk({ profile: res.rows[0] });
    } catch (e) {
      await client.query("ROLLBACK");
      throw e;
    } finally {
      client.release();
    }
  } catch (e) {
    console.error(e);
    return jsonError("Could not update profile", 400);
  }
}

export async function DELETE(req: Request, ctx: Ctx) {
  const userId = authUserId(req);
  if (!userId) return jsonError("Unauthorized", 401);
  const { id } = await ctx.params;

  const res = await pool.query(
    `DELETE FROM ai_profiles WHERE id = $1 AND user_id = $2 RETURNING id`,
    [id, userId],
  );
  if (!res.rows[0]) return jsonError("Profile not found", 404);
  return jsonOk({ deleted: true });
}
