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
      (await apiGet<{ episodes: AdminEpisode[] }>(`/admin/episodes?status=${status}&limit=100`, forwardHeaders(request)))?.episodes ?? [],
    status,
  };
}

const STATUS_FILTERS = ['all', 'pending', 'downloading', 'converting', 'transcribing', 'analyzing', 'done', 'failed', 'skipped'];

const STATUS_LABELS: Record<string, string> = {
  pending: '待处理',
  downloading: '下载中',
  converting: '转码中',
  transcribing: '转写中',
  analyzing: '分析中',
  done: '完成',
  failed: '失败',
  skipped: '跳过',
};

const STATUS_COLORS: Record<string, string> = {
  done: 'text-emerald-600',
  failed: 'text-red-600',
  skipped: 'text-stone-400',
};

export default function AdminEpisodes() {
  const { episodes, status } = useLoaderData<typeof loader>();
  const [, setSearchParams] = useSearchParams();

  return (
    <div className="mt-6 space-y-4">
      <div className="flex flex-wrap gap-1.5 text-xs">
        {STATUS_FILTERS.map((filter) => (
          <button
            key={filter}
            onClick={() => setSearchParams(filter === 'all' ? {} : { status: filter })}
            className={
              status === filter
                ? 'rounded-full bg-stone-900 px-2.5 py-1 text-white'
                : 'rounded-full bg-stone-100 px-2.5 py-1 text-stone-600 hover:bg-stone-200'
            }
          >
            {filter === 'all' ? '全部' : (STATUS_LABELS[filter] ?? filter)}
          </button>
        ))}
      </div>

      <div className="overflow-x-auto rounded-lg border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-stone-200 text-left text-xs text-stone-400">
              <th className="px-4 py-2.5">单集</th>
              <th className="px-4 py-2.5">播客</th>
              <th className="px-4 py-2.5">时长</th>
              <th className="px-4 py-2.5">状态</th>
              <th className="px-4 py-2.5">评分</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {episodes.length === 0 && (
              <tr>
                <td colSpan={5} className="px-4 py-8 text-center text-stone-400">
                  没有匹配的单集
                </td>
              </tr>
            )}
            {episodes.map((episode) => (
              <tr key={episode.id}>
                <td className="max-w-[18rem] px-4 py-2.5">
                  <div className="truncate font-medium text-stone-900" title={episode.title}>
                    {episode.title}
                  </div>
                  <div className="text-xs text-stone-400">{formatDate(episode.publishedAt)}</div>
                  {episode.transcribeError && (
                    <div className="mt-0.5 max-w-[18rem] truncate text-xs text-red-500" title={episode.transcribeError}>
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
                <td className={`px-4 py-2.5 ${STATUS_COLORS[episode.transcribeStatus] ?? 'text-stone-600'}`}>
                  {STATUS_LABELS[episode.transcribeStatus] ?? episode.transcribeStatus}
                </td>
                <td className="px-4 py-2.5">
                  {episode.score !== null ? (
                    <span className={episode.selected ? 'font-semibold text-emerald-700' : 'text-stone-400'}>
                      {episode.score}
                      {episode.selected ? ' ★' : ''}
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
