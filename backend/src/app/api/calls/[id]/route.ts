import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { query } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";
import { z } from "zod";

const patchSchema = z.object({
  summary: z.string().max(8000).optional(),
  transcript: z.unknown().optional(),
  endedAt: z.string().datetime().optional(),
  aiHandled: z.boolean().optional(),
  userApprovedAi: z.boolean().optional(),
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
    const res = await query(
      `UPDATE call_logs SET
         summary = COALESCE($1, summary),
         transcript = COALESCE($2::jsonb, transcript),
         ended_at = COALESCE($3::timestamptz, ended_at),
         ai_handled = COALESCE($4, ai_handled),
         user_approved_ai = COALESCE($5, user_approved_ai)
       WHERE id = $6 AND user_id = $7
       RETURNING id, summary, transcript, ended_at, ai_handled, user_approved_ai`,
      [
        body.summary ?? null,
        body.transcript ? JSON.stringify(body.transcript) : null,
        body.endedAt ?? null,
        body.aiHandled ?? null,
        body.userApprovedAi ?? null,
        id,
        userId,
      ],
    );
    if (!res.rows[0]) return jsonError("Call not found", 404);
    return jsonOk({ call: res.rows[0] });
  } catch (e) {
    console.error(e);
    return jsonError("Could not update call", 400);
  }
}
