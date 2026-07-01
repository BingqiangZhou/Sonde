export interface LlmConfig {
  apiKey: string;
  baseUrl: string;
  model: string;
}

export function loadLlmConfig(): LlmConfig {
  const apiKey = process.env.LLM_API_KEY;
  if (!apiKey) throw new Error("环境变量 LLM_API_KEY 未设置");
  return {
    apiKey,
    baseUrl: process.env.LLM_BASE_URL ?? "https://api.openai.com/v1",
    model: process.env.LLM_MODEL ?? "gpt-4o-mini",
  };
}

const SYSTEM_PROMPT = `你是一个播客内容摘要助手。给定剧集正文，请：
1. 生成一段 150-300 字的中文摘要，提炼核心观点。
2. 提取 2-5 个标签（简短词语）。
严格只返回 JSON，格式：{"summary": "...", "tags": ["...", "..."]}。不要包含其他文字或代码块标记。`;

export interface SummarizeOutput {
  summary: string;
  tags: string[];
}

export async function generateSummary(
  config: LlmConfig,
  title: string,
  content: string
): Promise<SummarizeOutput> {
  const userPrompt = `标题：${title}\n\n正文：\n${content.slice(0, 6000)}`;

  const res = await fetch(`${config.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${config.apiKey}`,
    },
    body: JSON.stringify({
      model: config.model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.3,
    }),
  });
  if (!res.ok) throw new Error(`LLM 请求失败: ${res.status}`);

  const body = (await res.json()) as { choices?: { message?: { content?: string } }[] };
  const content2 = body.choices?.[0]?.message?.content ?? "";
  const cleaned = content2.replace(/```json\s*|\s*```/g, "").trim();
  const parsed = JSON.parse(cleaned) as SummarizeOutput;
  return {
    summary: String(parsed.summary ?? "").trim(),
    tags: Array.isArray(parsed.tags) ? parsed.tags.map(String) : [],
  };
}
