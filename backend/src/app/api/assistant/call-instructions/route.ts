import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { getGroqApiKey, groqChatCompletion } from "@/lib/groq";
import { jsonError, jsonOk } from "@/lib/http";
import { z } from "zod";

const bodySchema = z.object({
  baseInstructions: z.string().min(1).max(8000),
  language: z.string().max(16).optional(),
  callerPhoneE164: z.string().max(24).optional(),
  callerDisplayName: z.string().max(120).optional(),
  model: z.string().max(64).optional(),
});

const META_SYSTEM = `You write ONE plain-text system prompt for a real-time VOICE phone assistant (the model will speak aloud on calls).
Output rules: output ONLY the final instructions text — no title, no markdown, no code fences, no preamble like "Here is".
Length: keep under 2800 characters (hard cap).
Behavior: short natural spoken sentences; one clarifying question only if needed; warm and professional; do not claim to be human; never read URLs letter-by-letter; respect safety and user boundaries.
If caller phone or name is unknown, ignore placeholders and stay generic.
The user's "base instructions" define role, tone, and boundaries — you must merge them in faithfully, only tightening for voice.`;

const MAX_OUT = 4500;

export async function POST(req: Request) {
  const token = bearerFromAuthHeader(req.headers.get("authorization"));
  if (!token) return jsonError("Missing bearer token", 401);
  try {
    verifyAccessToken(token);
  } catch {
    return jsonError("Invalid or expired token", 401);
  }

  let body: z.infer<typeof bodySchema>;
  try {
    body = bodySchema.parse(await req.json());
  } catch {
    return jsonError(
      "Invalid body: expected { baseInstructions, language?, callerPhoneE164?, callerDisplayName?, model? }",
      400,
    );
  }

  const base = body.baseInstructions.trim();

  if (!getGroqApiKey()) {
    return jsonOk({
      instructions: base,
      augmented: false,
      hint: "Set GROQ_API_KEY on the server for smarter call prompts (free: console.groq.com).",
    });
  }

  const userPayload = [
    `Preferred spoken language (ISO): ${body.language?.trim() || "en"}`,
    `Caller E.164 (optional): ${body.callerPhoneE164?.trim() || "unknown"}`,
    `Caller display name (optional): ${body.callerDisplayName?.trim() || "unknown"}`,
    "",
    "User base instructions (primary — honor fully):",
    base,
  ].join("\n");

  const r = await groqChatCompletion({
    messages: [
      { role: "system", content: META_SYSTEM },
      { role: "user", content: userPayload },
    ],
    model: body.model,
    maxTokens: 1800,
    temperature: 0.35,
  });

  if (!r.ok) {
    console.error("call-instructions Groq:", r.status, r.detail);
    return jsonOk({ instructions: base, augmented: false });
  }

  let text = r.text;
  if (!text) {
    return jsonOk({ instructions: base, augmented: false });
  }
  if (text.length > MAX_OUT) {
    text = text.slice(0, MAX_OUT);
  }
  return jsonOk({ instructions: text, augmented: true, model: r.model });
}
