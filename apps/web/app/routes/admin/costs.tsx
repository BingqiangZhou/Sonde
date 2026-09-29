import { useLoaderData } from 'react-router';

import { apiGet, forwardHeaders } from '~/lib/api.server.ts';

interface ReceiptRow {
  service: string;
  operation: string;
  model: string | null;
  inputTokens: number | null;
  outputTokens: number | null;
  audioSeconds: number | null;
  ok: boolean;
  error: string | null;
  durationMs: number | null;
  createdAt: string;
}

interface Costs {
  summary: {
    service: string;
    calls: number;
    failures: number;
    inputTokens: number;
    outputTokens: number;
    audioSeconds: number;
  }[];
  recent: ReceiptRow[];
}

export async function loader({ request }: { request: Request }) {
  return { costs: await apiGet<Costs>('/admin/costs', forwardHeaders(request)) };
}

export default function AdminCosts() {
  const { costs } = useLoaderData<typeof loader>();

  return (
    <div className="space-y-5">
      <section className="grid gap-3 sm:grid-cols-2">
        {costs?.summary.map((row) => (
          <div key={row.service} className="rounded-lg border border-stone-200 bg-white p-4">
            <div className="flex items-baseline justify-between">
              <span className="flex items-center gap-2 text-sm font-semibold text-ink">
                <span
                  className={`h-2 w-2 rounded-full ${row.service === 'llm' ? 'bg-violet-500' : 'bg-amber-500'}`}
                />
                {row.service === 'llm' ? 'LLM 调用' : '音频转写'}
              </span>
              <span className="text-[11px] tracking-wider text-stone-400">近 30 天</span>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-y-1.5 text-xs text-stone-600">
              <span className="text-stone-400">调用次数</span>
              <span>
                {row.calls}
                {row.failures > 0 && <span className="text-red-500">（失败 {row.failures}）</span>}
              </span>
              {row.service === 'llm' ? (
                <>
                  <span className="text-stone-400">tokens 用量</span>
                  <span>
                    {(row.inputTokens + row.outputTokens).toLocaleString()}
                    <span className="text-stone-400">
                      {' '}
                      （入 {row.inputTokens.toLocaleString()} / 出 {row.outputTokens.toLocaleString()}）
                    </span>
                  </span>
                </>
              ) : (
                <>
                  <span className="text-stone-400">音频总量</span>
                  <span>{Math.round(row.audioSeconds / 60).toLocaleString()} 分钟</span>
                </>
              )}
            </div>
          </div>
        ))}
        {(!costs || costs.summary.length === 0) && (
          <p className="col-span-2 rounded-lg border border-dashed border-stone-300 bg-white/50 py-10 text-center text-stone-400">
            还没有调用记录
          </p>
        )}
      </section>

      <section className="overflow-x-auto rounded-lg border border-stone-200 bg-white">
        <table className="w-full text-xs">
          <thead>
            <tr className="border-b border-stone-200 bg-stone-50/70 text-left text-[11px] uppercase tracking-wider text-stone-400">
              <th className="px-3 py-2">时间</th>
              <th className="px-3 py-2">服务</th>
              <th className="px-3 py-2">操作</th>
              <th className="px-3 py-2">模型</th>
              <th className="px-3 py-2">用量</th>
              <th className="px-3 py-2">耗时</th>
              <th className="px-3 py-2">结果</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {(costs?.recent ?? []).map((receipt, index) => (
              <tr key={index} className="hover:bg-stone-50/60">
                <td className="whitespace-nowrap px-3 py-2 text-stone-500">
                  {new Date(receipt.createdAt).toLocaleString('zh-CN', { hour12: false })}
                </td>
                <td className="px-3 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 ${
                      receipt.service === 'llm' ? 'bg-violet-50 text-violet-700' : 'bg-amber-50 text-amber-700'
                    }`}
                  >
                    {receipt.service === 'llm' ? 'LLM' : '转写'}
                  </span>
                </td>
                <td className="px-3 py-2 text-stone-500">{receipt.operation}</td>
                <td className="max-w-[10rem] truncate px-3 py-2 text-stone-500" title={receipt.model ?? ''}>
                  {receipt.model ?? '—'}
                </td>
                <td className="px-3 py-2 text-stone-500">
                  {receipt.service === 'llm'
                    ? `${receipt.inputTokens ?? 0}+${receipt.outputTokens ?? 0}`
                    : `${Math.round((receipt.audioSeconds ?? 0) / 60)} 分钟`}
                </td>
                <td className="px-3 py-2 text-stone-500">
                  {receipt.durationMs ? `${(receipt.durationMs / 1000).toFixed(1)}s` : '—'}
                </td>
                <td className={`px-3 py-2 ${receipt.ok ? 'text-emerald-600' : 'text-red-600'}`}>
                  {receipt.ok ? '成功' : (receipt.error?.slice(0, 30) ?? '失败')}
                </td>
              </tr>
            ))}
            {(costs?.recent ?? []).length === 0 && (
              <tr>
                <td colSpan={7} className="px-3 py-10 text-center text-stone-400">
                  暂无调用明细
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </section>
    </div>
  );
}
