import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { query } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";

export async function GET(req: Request) {
  const token = bearerFromAuthHeader(req.headers.get("authorization"));
  if (!token) return jsonError("Missing bearer token", 401);

  try {
    const { sub } = verifyAccessToken(token);
    const res = await query<{
      id: string;
      phone_e164: string;
      display_name: string;
      created_at: string;
    }>(
      `SELECT id, phone_e164, display_name, created_at FROM users WHERE id = $1`,
      [sub],
    );
    const user = res.rows[0];
    if (!user) return jsonError("User not found", 404);
    return jsonOk({ user });
  } catch {
    return jsonError("Invalid or expired token", 401);
  }
}
