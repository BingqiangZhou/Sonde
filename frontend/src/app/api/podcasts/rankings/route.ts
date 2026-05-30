import { NextRequest, NextResponse } from "next/server";
import { fetchRankings } from "@/lib/xyzrank-api";

export async function GET(req: NextRequest) {
  try {
    const offset = parseInt(req.nextUrl.searchParams.get("offset") ?? "0", 10);
    const limit = parseInt(req.nextUrl.searchParams.get("limit") ?? "50", 10);
    const data = await fetchRankings(offset, limit);
    return NextResponse.json({ success: true, data });
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : "Unknown error";
    return NextResponse.json(
      { success: false, error: { message } },
      { status: 500 }
    );
  }
}
