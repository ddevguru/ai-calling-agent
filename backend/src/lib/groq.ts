const GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions";

export const DEFAULT_GROQ_MODEL = "llama-3.1-8b-instant";

export function getGroqApiKey(): string | null {
  const k = process.env.GROQ_API_KEY?.trim();
  return k || null;
}

export function resolveGroqModel(override?: string | null): string {
  return (
    override?.trim() ||
    process.env.GROQ_MODEL?.trim() ||
    DEFAULT_GROQ_MODEL
  );
}

type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

type GroqApiBody = {
  choices?: Array<{ message?: { content?: string } }>;
  error?: { message?: string };
};

export type GroqChatResult =
  | { ok: true; text: string; model: string }
  | { ok: false; status: number; detail: string };

export async function groqChatCompletion(opts: {
  messages: ChatMessage[];
  model?: string | null;
  maxTokens?: number;
  temperature?: number;
}): Promise<GroqChatResult> {
  const key = getGroqApiKey();
  if (!key) {
    return { ok: false, status: 503, detail: "GROQ_API_KEY missing" };
  }

  const model = resolveGroqModel(opts.model);
  const res = await fetch(GROQ_CHAT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: opts.messages,
      temperature: opts.temperature ?? 0.5,
      max_tokens: opts.maxTokens ?? 1024,
    }),
  });

  const raw = await res.text();
  let data: GroqApiBody;
  try {
    data = JSON.parse(raw) as GroqApiBody;
  } catch {
    return { ok: false, status: 502, detail: "Non-JSON Groq response" };
  }

  if (!res.ok) {
    const msg = data.error?.message || raw.slice(0, 240);
    return { ok: false, status: res.status, detail: msg };
  }

  const text = data.choices?.[0]?.message?.content?.trim() ?? "";
  return { ok: true, text, model };
}
