#!/usr/bin/env node
/** 开发用 mock 服务：模拟 OpenAI 兼容 /chat/completions 与 /audio/transcriptions。
 *  用途：无真实 API key 时端到端跑通 转写→评分→写作→成刊 全链路。
 *  运行：node scripts/dev/mock-llm.mjs [port]（默认 9999） */

import { createServer } from 'node:http';

const port = Number.parseInt(process.argv[2] ?? '9999', 10);
let scoreCalls = 0;

const server = createServer(async (req, res) => {
  const url = req.url ?? '';

  if (req.method === 'POST' && url.endsWith('/audio/transcriptions')) {
    // 消费 multipart body
    await readBody(req);
    sendJson(res, 200, { text: '这是模拟转录文本。嘉宾详细讲述了模型能力边界与三个实际落地案例，包含具体数据与团队经验的反思。' });
    return;
  }

  if (req.method === 'POST' && url.endsWith('/chat/completions')) {
    const body = JSON.parse((await readBody(req)).toString('utf8'));
    const userPrompt = body.messages?.find((m) => m.role === 'user')?.content ?? '';

    let payload;
    if (userPrompt.includes('日报主编')) {
      payload = {
        title: '模型边界与落地经验成为今日主线',
        leadParagraph: '今天入选的单集集中讨论模型能力的真实边界与落地经验。多位主播不约而同提到数据回流被低估，值得关注的还有三个具体案例的成败复盘。',
        highlights: ['模型长任务规划仍有明显边界', '数据回流环节最容易被低估', '三个落地案例的成败复盘'],
      };
    } else if (userPrompt.includes('titleZh')) {
      payload = {
        titleZh: '模型能力边界与三个落地案例的经验复盘',
        summaryZh: '嘉宾基于团队实践给出判断：当前模型在长任务规划上仍有明显边界，并复盘了三个真实落地案例的成败得失，其中数据回流环节最容易被低估。',
        reasonZh: '一手经验复盘，案例具体可对照',
      };
    } else if (userPrompt.includes('注意力价值')) {
      // 每 3 次评分轮换低分，便于验证「全部动态」的入选/未入选两种呈现
      scoreCalls += 1;
      if (scoreCalls % 3 === 0) {
        payload = { score: 45, reason: '内容以新闻罗列为主，缺乏增量判断', category: 'business', tags: ['资讯罗列'] };
      } else {
        payload = { score: 88, reason: '一手信息密度高，含具体落地案例', category: 'tech-ai', tags: ['AI', '落地实践'] };
      }
    } else {
      sendJson(res, 400, { error: { message: 'mock: unknown prompt' } });
      return;
    }

    sendJson(res, 200, {
      choices: [{ message: { content: JSON.stringify(payload) } }],
      usage: { prompt_tokens: 1000, completion_tokens: 200 },
    });
    return;
  }

  sendJson(res, 404, { error: 'not found' });
});

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function sendJson(res, status, data) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(data));
}

server.listen(port, () => {
  console.log(`[mock-llm] listening on :${port} (/v1/chat/completions, /v1/audio/transcriptions)`);
});
