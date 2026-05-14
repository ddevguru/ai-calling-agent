import { loginSchema, signAccessToken, verifyPassword } from "@/lib/auth";
import { query } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";

export async function POST(req: Request) {
  try {
    const body = loginSchema.parse(await req.json());
    const res = await query<{
      id: string;
      phone_e164: string;
      password_hash: string;
    }>(
      `SELECT id, phone_e164, password_hash FROM users WHERE phone_e164 = $1`,
      [body.phoneE164],
    );
    const row = res.rows[0];
    if (!row) return jsonError("Invalid phone or password", 401);

    const ok = await verifyPassword(body.password, row.password_hash);
    if (!ok) return jsonError("Invalid phone or password", 401);

    const token = signAccessToken({ sub: row.id, phone: row.phone_e164 });
    return jsonOk({ token, userId: row.id, phoneE164: row.phone_e164 });
  } catch (e: unknown) {
    if (e && typeof e === "object" && "issues" in e) {
      return jsonError("Invalid payload", 422);
    }
    console.error(e);
    return jsonError("Login failed", 500);
  }
}
