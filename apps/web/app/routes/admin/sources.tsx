import { useLoaderData, useRevalidator } from 'react-router';
import { useState } from 'react';

import { adminGet, adminSend } from '~/lib/admin-api.ts';
import { apiGet, forwardHeaders } from '~/lib/api.server.ts';

interface AdminSource {
  id: number;
  name: string;
  feedUrl: string;
  tier: string;
  intervalMinutes: number;
  isActive: boolean;
  lastFetchedAt: string | null;
  health: { lastStatus?: string; lastError?: string | null; consecutiveFailures?: number };
}

interface DiscoveredPodcast {
  collectionId: number;
  name: string;
  author: string | null;
  genre: string | null;
  trackCount: number | null;
  artworkUrl: string | null;
  feedUrl: string | null;
  appleUrl: string | null;
  rank: number | null;
  stores: string[];
  subscribed: boolean;
}

interface DiscoverResponse {
  countries: string[];
  total: number;
  results: DiscoveredPodcast[];
}

export async function loader({ request }: { request: Request }) {
  return {
    sources: (await apiGet<{ sources: AdminSource[] }>('/admin/sources', forwardHeaders(request)))?.sources ?? [],
  };
}

function feedHost(url: string): string {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
}

export default function AdminSources() {
  const { sources } = useLoaderData<typeof loader>();
  const revalidator = useRevalidator();
  const [busy, setBusy] = useState<number | string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', feedUrl: '', tier: 'T2', intervalMinutes: 60 });

  // ── 发现播客（iTunes 多国商店）──
  const [tab, setTab] = useState<'search' | 'top'>('search');
  const [term, setTerm] = useState('');
  const [countries, setCountries] = useState<string[]>([]);
  const [chartCountry, setChartCountry] = useState<string | null>(null);
  const [results, setResults] = useState<DiscoveredPodcast[]>([]);
  const [searched, setSearched] = useState(false);
  const [loading, setLoading] = useState(false);
  const [discoverError, setDiscoverError] = useState<string | null>(null);
  const [subscribing, setSubscribing] = useState<number | null>(null);

  async function runSearch() {
    const q = term.trim();
    if (!q) {
      return;
    }
    setLoading(true);
    setDiscoverError(null);
    try {
      const data = await adminGet<DiscoverResponse>(`/sources/discover?q=${encodeURIComponent(q)}`);
      setCountries(data.countries);
      setResults(data.results);
    } catch (err) {
      setDiscoverError(err instanceof Error ? err.message : '搜索失败');
    } finally {
      setSearched(true);
      setLoading(false);
    }
  }

  async function loadChart(country?: string) {
    setLoading(true);
    setDiscoverError(null);
    try {
      const params = new URLSearchParams({ chart: 'top', limit: '50' });
      if (country) {
        params.set('country', country);
      }
      const data = await adminGet<DiscoverResponse>(`/sources/discover?${params.toString()}`);
      setCountries(data.countries);
      setChartCountry(country ?? data.countries[0] ?? null);
      setResults(data.results);
    } catch (err) {
      setDiscoverError(err instanceof Error ? err.message : '榜单加载失败');
    } finally {
      setSearched(true);
      setLoading(false);
    }
  }

  function switchTab(next: 'search' | 'top') {
    if (tab === next) {
      return;
    }
    setTab(next);
    setResults([]);
    setSearched(false);
    setDiscoverError(null);
    if (next === 'top') {
      void loadChart();
    }
  }

  async function subscribe(podcast: DiscoveredPodcast) {
    if (!podcast.feedUrl) {
      return;
    }
    setSubscribing(podcast.collectionId);
    setDiscoverError(null);
    try {
      await adminSend('/sources/subscribe', 'POST', { name: podcast.name, feedUrl: podcast.feedUrl });
      setResults((prev) =>
        prev.map((item) => (item.collectionId === podcast.collectionId ? { ...item, subscribed: true } : item)),
      );
      revalidator.revalidate();
    } catch (err) {
      setDiscoverError(err instanceof Error ? err.message : '订阅失败');
    } finally {
      setSubscribing(null);
    }
  }

  async function run(key: number | string, fn: () => Promise<unknown>) {
    setBusy(key);
    setError(null);
    try {
      await fn();
      revalidator.revalidate();
    } catch (err) {
      setError(err instanceof Error ? err.message : '操作失败');
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="space-y-6">
      <section className="rounded-lg border border-stone-200 bg-white p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-sm font-semibold text-stone-500">发现播客</h2>
          <div className="flex rounded-md border border-stone-200 p-0.5 text-xs">
            <button
              onClick={() => switchTab('search')}
              className={`rounded px-3 py-1 transition-colors ${tab === 'search' ? 'bg-ink text-paper' : 'text-stone-500 hover:text-ink'}`}
            >
              搜索
            </button>
            <button
              onClick={() => switchTab('top')}
              className={`rounded px-3 py-1 transition-colors ${tab === 'top' ? 'bg-ink text-paper' : 'text-stone-500 hover:text-ink'}`}
            >
              热门榜
            </button>
          </div>
        </div>

        {tab === 'search' ? (
          <form
            className="mt-4 flex gap-2"
            onSubmit={(event) => {
              event.preventDefault();
              void runSearch();
            }}
          >
            <input
              value={term}
              onChange={(e) => setTerm(e.target.value)}
              placeholder="搜索播客名称…"
              className="flex-1 rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-vermilion focus:outline-none"
            />
            <button
              type="submit"
              disabled={loading || term.trim() === ''}
              className="rounded-md bg-ink px-4 py-2 text-sm font-medium text-paper transition-colors hover:bg-vermilion disabled:opacity-50"
            >
              {loading ? '搜索中…' : '搜索'}
            </button>
          </form>
        ) : (
          <div className="mt-4 flex flex-wrap gap-1.5">
            {countries.map((country) => (
              <button
                key={country}
                onClick={() => {
                  setChartCountry(country);
                  void loadChart(country);
                }}
                disabled={loading}
                className={`rounded border px-2.5 py-1 text-xs transition-colors ${
                  chartCountry === country
                    ? 'border-ink bg-ink text-paper'
                    : 'border-stone-200 text-stone-500 hover:border-stone-400 hover:text-ink'
                } disabled:opacity-50`}
              >
                {country}
              </button>
            ))}
          </div>
        )}

        {discoverError && <p className="mt-3 text-xs text-red-600">{discoverError}</p>}

        <ul className="mt-4 divide-y divide-stone-100">
          {loading && results.length === 0 && (
            <li className="py-6 text-center text-sm text-stone-400">加载中…</li>
          )}
          {!loading && searched && results.length === 0 && !discoverError && (
            <li className="py-6 text-center text-sm text-stone-400">没有找到相关播客</li>
          )}
          {results.map((podcast) => (
            <li key={podcast.collectionId} className="flex items-center gap-3 py-2.5">
              {podcast.rank !== null && (
                <span className="w-6 shrink-0 text-right text-sm tabular-nums text-stone-400">{podcast.rank}</span>
              )}
              {podcast.artworkUrl && (
                <img
                  src={podcast.artworkUrl}
                  alt=""
                  loading="lazy"
                  className="h-10 w-10 shrink-0 rounded border border-stone-200 object-cover"
                />
              )}
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <span className="truncate text-sm font-medium text-ink">{podcast.name}</span>
                  {podcast.stores.map((store) => (
                    <span
                      key={store}
                      className="shrink-0 rounded-sm border border-stone-200 px-1 text-[10px] uppercase text-stone-400"
                    >
                      {store}
                    </span>
                  ))}
                  {podcast.subscribed && (
                    <span className="shrink-0 rounded-sm bg-emerald-50 px-1 text-[10px] text-emerald-700">已订阅</span>
                  )}
                </div>
                <div className="truncate text-xs text-stone-400">
                  {[podcast.author, podcast.genre, podcast.trackCount !== null ? `${podcast.trackCount} 集` : null]
                    .filter(Boolean)
                    .join(' · ')}
                  {podcast.feedUrl && ` · ${feedHost(podcast.feedUrl)}`}
                </div>
              </div>
              {podcast.appleUrl && (
                <a
                  href={podcast.appleUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="shrink-0 text-xs text-stone-500 hover:text-vermilion"
                >
                  Apple
                </a>
              )}
              <button
                onClick={() => void subscribe(podcast)}
                disabled={!podcast.feedUrl || podcast.subscribed || subscribing !== null}
                title={podcast.feedUrl ?? '该节目未提供 RSS'}
                className="shrink-0 rounded-md border border-stone-300 px-3 py-1.5 text-xs font-medium text-ink transition-colors hover:border-vermilion hover:text-vermilion disabled:cursor-not-allowed disabled:opacity-50"
              >
                {podcast.subscribed
                  ? '已订阅'
                  : !podcast.feedUrl
                    ? '无 RSS'
                    : subscribing === podcast.collectionId
                      ? '订阅中…'
                      : '订阅'}
              </button>
            </li>
          ))}
        </ul>

        <p className="mt-3 text-[11px] text-stone-400">
          数据来自 Apple Podcasts（iTunes Search API）
          {tab === 'search' && countries.length > 0 && `，同时在 ${countries.join(' / ')} 商店检索并去重`}
        </p>
      </section>

      <section className="rounded-lg border border-stone-200 bg-white p-5">
        <h2 className="text-sm font-semibold text-stone-500">添加订阅源</h2>
        <form
          className="mt-4 grid gap-3 sm:grid-cols-[1fr_1fr_5rem_6rem_auto]"
          onSubmit={async (event) => {
            event.preventDefault();
            await run('add', () => adminSend('/sources', 'POST', form));
            setForm({ name: '', feedUrl: '', tier: 'T2', intervalMinutes: 60 });
          }}
        >
          <input
            required
            placeholder="播客名称"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className="rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-vermilion focus:outline-none"
          />
          <input
            required
            type="url"
            placeholder="RSS 地址 https://…"
            value={form.feedUrl}
            onChange={(e) => setForm({ ...form, feedUrl: e.target.value })}
            className="rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-vermilion focus:outline-none"
          />
          <select
            value={form.tier}
            onChange={(e) => setForm({ ...form, tier: e.target.value })}
            className="rounded-md border border-stone-300 bg-white px-2 py-2 text-sm"
            title="T1=高优先（门槛 60），T2=一般（门槛 70）"
          >
            <option value="T1">T1</option>
            <option value="T2">T2</option>
          </select>
          <input
            type="number"
            min={5}
            max={1440}
            value={form.intervalMinutes}
            onChange={(e) => setForm({ ...form, intervalMinutes: Number(e.target.value) })}
            className="rounded-md border border-stone-300 px-2 py-2 text-sm"
            title="抓取间隔（分钟）"
          />
          <button
            type="submit"
            disabled={busy !== null}
            className="rounded-md bg-ink px-4 py-2 text-sm font-medium text-paper transition-colors hover:bg-vermilion disabled:opacity-50"
          >
            {busy === 'add' ? '添加中…' : '添加'}
          </button>
        </form>
        <p className="mt-2 text-[11px] text-stone-400">
          分级说明：T1 = 高优先播客（入选门槛 60 分），T2 = 一般播客（入选门槛 70 分），可在 industry/selection.ts 调整。
        </p>
        {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
      </section>

      <section className="overflow-x-auto rounded-lg border border-stone-200 bg-white">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-stone-200 bg-stone-50/70 text-left text-[11px] uppercase tracking-wider text-stone-400">
              <th className="px-4 py-2.5">名称</th>
              <th className="px-4 py-2.5">分级</th>
              <th className="px-4 py-2.5">间隔</th>
              <th className="px-4 py-2.5">状态</th>
              <th className="px-4 py-2.5">最近抓取</th>
              <th className="px-4 py-2.5 text-right">操作</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-stone-100">
            {sources.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-stone-400">
                  还没有订阅源，用上方表单添加第一个播客
                </td>
              </tr>
            )}
            {sources.map((source) => (
              <tr key={source.id} className={`hover:bg-stone-50/60 ${source.isActive ? '' : 'opacity-50'}`}>
                <td className="px-4 py-2.5">
                  <div className="font-medium text-ink">{source.name}</div>
                  <div className="max-w-[16rem] truncate text-xs text-stone-400" title={source.feedUrl}>
                    {source.feedUrl}
                  </div>
                </td>
                <td className="px-4 py-2.5">
                  <select
                    value={source.tier}
                    onChange={(e) =>
                      run(source.id, () => adminSend(`/sources/${source.id}`, 'PATCH', { tier: e.target.value }))
                    }
                    className="rounded border border-stone-200 bg-white px-1.5 py-1 text-xs"
                  >
                    <option value="T1">T1</option>
                    <option value="T2">T2</option>
                  </select>
                </td>
                <td className="px-4 py-2.5 text-stone-500">{source.intervalMinutes} 分</td>
                <td className="px-4 py-2.5">
                  {source.health?.lastStatus === 'ok' ? (
                    <span className="inline-flex items-center gap-1 text-emerald-600">
                      <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
                      正常
                    </span>
                  ) : source.health?.lastError ? (
                    <span
                      className="inline-flex items-center gap-1 text-red-600"
                      title={source.health.lastError}
                    >
                      <span className="h-1.5 w-1.5 rounded-full bg-red-500" />
                      异常{source.health.consecutiveFailures ? ` ×${source.health.consecutiveFailures}` : ''}
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 text-stone-400">
                      <span className="h-1.5 w-1.5 rounded-full bg-stone-300" />
                      未抓取
                    </span>
                  )}
                </td>
                <td className="px-4 py-2.5 text-xs text-stone-400">
                  {source.lastFetchedAt ? new Date(source.lastFetchedAt).toLocaleString('zh-CN', { hour12: false }) : '—'}
                </td>
                <td className="whitespace-nowrap px-4 py-2.5 text-right text-xs">
                  <button
                    onClick={() => run(source.id, () => adminSend(`/sources/${source.id}/fetch-now`, 'POST'))}
                    disabled={busy !== null}
                    className="rounded px-2 py-1 text-stone-600 hover:bg-stone-100 disabled:opacity-50"
                  >
                    立即抓取
                  </button>
                  <button
                    onClick={() =>
                      run(source.id, () =>
                        adminSend(`/sources/${source.id}`, 'PATCH', { isActive: !source.isActive }),
                      )
                    }
                    disabled={busy !== null}
                    className="rounded px-2 py-1 text-stone-600 hover:bg-stone-100 disabled:opacity-50"
                  >
                    {source.isActive ? '停用' : '启用'}
                  </button>
                  <button
                    onClick={() => run(source.id, () => adminSend(`/sources/${source.id}`, 'DELETE'))}
                    disabled={busy !== null}
                    className="rounded px-2 py-1 text-red-600 hover:bg-red-50 disabled:opacity-50"
                  >
                    删除
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
