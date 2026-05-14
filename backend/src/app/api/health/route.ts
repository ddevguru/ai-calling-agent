import { jsonOk } from "@/lib/http";

export async function GET() {
  return jsonOk({ ok: true, service: "ai-phone-assistant-api" });
}
