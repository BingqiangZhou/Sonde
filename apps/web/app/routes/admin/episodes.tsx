import { useLoaderData, useSearchParams } from 'react-router';

import { apiGet, forwardHeaders } from '~/lib/api.server.ts';
import { formatDate, formatDuration } from '~/lib/format.ts';

interface AdminEpisode {
  id: number;
  title: string;
  podcast: string;
  publishedAt: string | null;
  durationSeconds: number | null;
  transcribeStatus: string;
  transcribeError: string | null;
  score: number | null;
  selected: boolean | null;
  category: string | null;
}

export async function loader({ request }: { request: Request }) {
  const url = new URL(request.url);
  const status = url.searchParams.get('status') ?? 'all';
  return {
    episodes:
      (await apiGet<{ episodes: AdminEpisode[] }>(`/admin/episodes?status=${status}&limit=100`, forwardHeaders(request)))
        ?.episodes ?? [],
    status,
  };
}

const STATUS_FILTERS = [
  'all',
  'pending',
  'downloading',
  'converting',
  'transcribing',
  'analyzing',
  'done',
  'failed',
  'skipped',
];

const STATUS_LABELS: Record<string, string> = {
  all: '全部',
  pending: '待处理',
  downloading: '下载中',
  converting: '转码中',
  transcribing: '转写中',
  analyzing: '分析中',
  done: '完成',
  failed: '失败',
  skipped: '跳过',
};

const STATUS_DOTS: Record<string, string> = {
  pending: 'bg-stone-300',
  downloading: 'bg-blue-500',
  converting: 'bg-blue-500',
  transcribing: 'bg-amber-500',
  analyzing: 'bg-violet-500',
  done: 'bg-emerald-500',
  failed: 'bg-red-500',
  skipped: 'bg-stone-300',
};

const STATUS_TEXT: Record<string, string> = {
  done: 'text-emerald-600',
  failed: 'text-red-600',
  skipped: 'text-stone-400',
};

export default function AdminEpisodes() {
  const { episodes, status } = useLoaderData<typeof loader>();
  const [, setSearchParams] = useSearchParams();

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-1.5 text-xs">
        {STATUS_FILTERS.map((filter) => (
          <button
            key={filter}
            onClick={() => setSearchParams(filter === 'all' ? {} : { status: filter })}
            className={
              status === filter
                ? 'rounded-full bg-ink px-2.5 py-1 font-medium text-paper'
                : 'rounded-full bg-white px-2.5 py-1 text-stone-600 ring-1 ring-stone-200 hover:bg-stone-50'
            }
          >
            {STATUS_LABELS[filter] ?? filter}
          </button>
        ))}
      </div>

      <div className="overflow-x-auto rounded-lg border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-stone-200 bg-stone-50/70 text-left text-[11px] uppercase tracking-wider text-stone-400">
              <th className="px-4 py-2.5">单集</th>
              <th className="px-4 py-2.5">播客</th>
              <th className="px-4 py-2.5">时长</th>
              <th className="px-4 py-2.5">状态</th>
              <th className="px-4 py-2.5 text-right">评分</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {episodes.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-10 text-center text-stone-400">
                  没有匹配的单集
                </td>
              </tr>
            )}
            {episodes.map((episode) => (
              <tr key={episode.id} className="hover:bg-stone-50/60">
                <td className="max-w-[18rem] px-4 py-2.5">
                  <div className="truncate font-medium text-ink" title={episode.title}>
                    {episode.title}
                  </div>
                  <div className="text-xs text-stone-400">{formatDate(episode.publishedAt)}</div>
                  {episode.transcribeError && (
                    <div
                      className="mt-0.5 max-w-[18rem] truncate text-xs text-red-500"
                      title={episode.transcribeError}
                    >
                      {episode.transcribeError}
                    </div>
                  )}
                </td>
                <td className="max-w-[8rem] truncate px-4 py-2.5 text-stone-500" title={episode.podcast}>
                  {episode.podcast}
                </td>
                <td className="px-4 py-2.5 text-xs text-stone-400">
                  {formatDuration(episode.durationSeconds) || '—'}
                </td>
                <td className="px-4 py-2.5">
                  <span className={`inline-flex items-center gap-1.5 ${STATUS_TEXT[episode.transcribeStatus] ?? 'text-stone-600'}`}>
                    <span className={`h-1.5 w-1.5 rounded-full ${STATUS_DOTS[episode.transcribeStatus] ?? 'bg-stone-300'}`} />
                    {STATUS_LABELS[episode.transcribeStatus] ?? episode.transcribeStatus}
                  </span>
                </td>
                <td className="px-4 py-2.5 text-right">
                  {episode.score !== null ? (
                    <span
                      className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 font-serif text-sm font-semibold ${
                        episode.selected ? 'bg-vermilion/10 text-vermilion' : 'bg-stone-100 text-stone-400'
                      }`}
                    >
                      {episode.score}
                      {episode.selected && <span className="text-[10px]">★</span>}
                    </span>
                  ) : (
                    <span className="text-stone-300">—</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
