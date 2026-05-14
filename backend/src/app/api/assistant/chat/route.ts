import { bearerFromAuthHeader, verifyAccessToken } from "@/lib/auth";
import { groqChatCompletion } from "@/lib/groq";
import { jsonError, jsonOk } from "@/lib/http";
import { z } from "zod";

const bodySchema = z.object({
  message: z.string().min(1).max(8000),
  system: z.string().max(4000).optional(),
  model: z.string().max(64).optional(),
});

export async function POST(req: Request) {
  const token = bearerFromAuthHeader(req.headers.get("authorization"));
  if (!token) return jsonError("Missing bearer token", 401);
  try {
    verifyAccessToken(token);
  } catch {
    return jsonError("Invalid or expired token", 401);
  }

  if (!process.env.GROQ_API_KEY?.trim()) {
    return jsonError(
      "Server missing GROQ_API_KEY. Add a free key from https://console.groq.com in Render env vars.",
      503,
    );
  }

  let body: z.infer<typeof bodySchema>;
  try {
    body = bodySchema.parse(await req.json());
  } catch {
    return jsonError("Invalid body: expected { message, system?, model? }", 400);
  }

  const messages: Array<{ role: "system" | "user"; content: string }> = [];
  if (body.system?.trim()) {
    messages.push({ role: "system", content: body.system.trim() });
  }
  messages.push({ role: "user", content: body.message });

  const r = await groqChatCompletion({
    messages,
    model: body.model,
    maxTokens: 1024,
    temperature: 0.5,
  });

  if (!r.ok) {
    console.error("Groq chat error", r.status, r.detail);
    const status = r.status === 503 ? 503 : r.status >= 500 ? 502 : 400;
    return jsonError(r.detail || "Assistant request failed", status);
  }

  return jsonOk({ reply: r.text, model: r.model });
}
