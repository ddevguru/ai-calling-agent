import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { query } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";
import { z } from "zod";

const createCallSchema = z.object({
  direction: z.enum(["inbound", "outbound"]),
  peerE164: z.string().regex(/^\+[1-9]\d{6,14}$/),
  aiProfileId: z.string().uuid().optional(),
  aiHandled: z.boolean().optional(),
  userApprovedAi: z.boolean().optional(),
  transcript: z.unknown().optional(),
  summary: z.string().max(8000).optional(),
  startedAt: z.string().datetime().optional(),
  endedAt: z.string().datetime().optional(),
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

  const { searchParams } = new URL(req.url);
  const limit = Math.min(Number(searchParams.get("limit") ?? "50"), 200);

  const res = await query(
    `SELECT id, direction, peer_e164, started_at, ended_at, ai_handled,
            user_approved_ai, ai_profile_id, summary
     FROM call_logs
     WHERE user_id = $1
     ORDER BY started_at DESC
     LIMIT $2`,
    [userId, limit],
  );
  return jsonOk({ calls: res.rows });
}

export async function POST(req: Request) {
  const userId = authUserId(req);
  if (!userId) return jsonError("Unauthorized", 401);

  try {
    const body = createCallSchema.parse(await req.json());
    const res = await query(
      `INSERT INTO call_logs (
         user_id, direction, peer_e164, started_at, ended_at,
         ai_profile_id, ai_handled, user_approved_ai, transcript, summary
       ) VALUES (
         $1, $2, $3,
         COALESCE($4::timestamptz, now()),
         $5::timestamptz,
         $6, $7, $8, $9::jsonb, $10
       )
       RETURNING id, direction, peer_e164, started_at, ended_at, ai_handled, summary`,
      [
        userId,
        body.direction,
        body.peerE164,
        body.startedAt ?? null,
        body.endedAt ?? null,
        body.aiProfileId ?? null,
        body.aiHandled ?? false,
        body.userApprovedAi ?? null,
        body.transcript ? JSON.stringify(body.transcript) : null,
        body.summary ?? null,
      ],
    );
    return jsonOk({ call: res.rows[0] }, 201);
  } catch (e) {
    console.error(e);
    return jsonError("Could not create call log", 400);
  }
}
