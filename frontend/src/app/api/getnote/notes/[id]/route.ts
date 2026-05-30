import { NextRequest, NextResponse } from "next/server";
import * as getnote from "@/lib/getnote-api";

function getCredentials(req: NextRequest) {
  const apiKey = req.headers.get("X-Api-Key");
  const clientId = req.headers.get("X-Client-ID");
  if (!apiKey || !clientId) {
    throw new Error("Get笔记 API Key 或 Client ID 未配置");
  }
  return { apiKey, clientId };
}

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { apiKey, clientId } = getCredentials(_req);
    const { id } = await params;
    const data = await getnote.getNoteDetail(apiKey, clientId, id);
    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : "Unknown error";
    const code = typeof (e as Record<string, unknown>)?.code === "number" ? (e as Record<string, unknown>).code as number : 0;
    return NextResponse.json(
      { success: false, error: { message, code } },
      { status: code === 42900 ? 429 : 500 }
    );
  }
}
