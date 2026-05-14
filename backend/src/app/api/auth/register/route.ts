import { hashPassword, registerSchema, signAccessToken } from "@/lib/auth";
import { query } from "@/lib/db";
import { jsonError, jsonOk } from "@/lib/http";

export async function POST(req: Request) {
  try {
    const body = registerSchema.parse(await req.json());
    const passwordHash = await hashPassword(body.password);

    const userRes = await query<{ id: string; phone_e164: string }>(
      `INSERT INTO users (phone_e164, password_hash, display_name)
       VALUES ($1, $2, $3)
       RETURNING id, phone_e164`,
      [body.phoneE164, passwordHash, body.displayName ?? ""],
    );

    const user = userRes.rows[0];
    if (!user) return jsonError("Could not create user", 500);

    await query(
      `INSERT INTO ai_profiles (user_id, name, instructions, voice_id, language, is_default)
       VALUES ($1, $2, $3, $4, $5, true)`,
      [
        user.id,
        "Default",
        "You answer phone calls politely and concisely on behalf of the user.",
        "alloy",
        "en",
      ],
    );

    const token = signAccessToken({ sub: user.id, phone: user.phone_e164 });
    return jsonOk({ token, userId: user.id, phoneE164: user.phone_e164 });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    if (String(msg).includes("users_phone_e164_key")) {
      return jsonError("Phone number already registered", 409);
    }
    if (e && typeof e === "object" && "issues" in e) {
      return jsonError("Invalid payload", 422);
    }
    console.error(e);
    return jsonError("Registration failed", 500);
  }
}
