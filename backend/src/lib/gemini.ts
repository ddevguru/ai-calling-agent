const GEMINI_GENERATE_BASE =
  "https://generativelanguage.googleapis.com/v1beta/models";

export const DEFAULT_GEMINI_MODEL = "gemini-2.0-flash";

export function getGeminiApiKey(): string | null {
  const k = process.env.GEMINI_API_KEY?.trim();
  return k || null;
}

export function resolveGeminiModel(override?: string | null): string {
  return (
    override?.trim() ||
    process.env.GEMINI_MODEL?.trim() ||
    DEFAULT_GEMINI_MODEL
  );
}

type GeminiBody = {
  candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  error?: { message?: string };
};

export type GeminiGenerateResult =
  | { ok: true; text: string; model: string }
  | { ok: false; status: number; detail: string };

/**
 * Google AI Studio free-tier compatible REST call (no SDK dependency).
 */
export async function geminiGenerateText(opts: {
  systemInstruction: string;
  userText: string;
  model?: string | null;
  temperature?: number;
  maxOutputTokens?: number;
}): Promise<GeminiGenerateResult> {
  const key = getGeminiApiKey();
  if (!key) {
    return { ok: false, status: 503, detail: "GEMINI_API_KEY missing" };
  }

  const model = resolveGeminiModel(opts.model);
  const url = `${GEMINI_GENERATE_BASE}/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(key)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: opts.systemInstruction }],
      },
      contents: [
        {
          role: "user",
          parts: [{ text: opts.userText }],
        },
      ],
      generationConfig: {
        temperature: opts.temperature ?? 0.35,
        maxOutputTokens: opts.maxOutputTokens ?? 2048,
      },
    }),
  });

  const raw = await res.text();
  let data: GeminiBody;
  try {
    data = JSON.parse(raw) as GeminiBody;
  } catch {
    return { ok: false, status: 502, detail: "Non-JSON Gemini response" };
  }

  if (!res.ok) {
    const msg = data.error?.message || raw.slice(0, 280);
    return { ok: false, status: res.status, detail: msg };
  }

  const text =
    data.candidates?.[0]?.content?.parts?.map((p) => p.text ?? "").join("") ??
    "";

  const trimmed = text.trim();
  return { ok: true, text: trimmed, model };
}
