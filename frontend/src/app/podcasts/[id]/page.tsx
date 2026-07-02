import Image from 'next/image';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Clock } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { loadPodcastMeta, loadEpisodes, listPodcastIds } from '@/lib/loaders';

export async function generateStaticParams() {
  const ids = await listPodcastIds();
  return ids.map((id) => ({ id }));
}

function formatDate(s: string): string {
  try { return new Date(s).toLocaleDateString('zh-CN'); } catch { return s; }
}

function formatDuration(seconds: number): string {
  if (!seconds || seconds <= 0) return '';
  const mins = Math.floor(seconds / 60);
  const hrs = Math.floor(mins / 60);
  if (hrs > 0) return `${hrs}小时${mins % 60 > 0 ? ` ${mins % 60}分钟` : ''}`;
  return `${mins}分钟`;
}

export default async function PodcastDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const meta = await loadPodcastMeta(id);
  if (!meta) notFound();
  const episodes = await loadEpisodes(id);

  return (
    <div className="space-y-6">
      <Link href="/podcasts" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="h-4 w-4" />
        返回排行榜
      </Link>

      <Card>
        <CardContent className="p-6">
          <div className="flex flex-col gap-6 sm:flex-row sm:items-start">
            <div className="relative h-24 w-24 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
              {meta.logo_url ? (
                <Image src={meta.logo_url} alt={meta.name} fill className="object-cover" sizes="96px" />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-3xl font-bold text-muted-foreground">{meta.name.charAt(0)}</div>
              )}
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="text-xl font-bold">{meta.name}</h1>
              <p className="mt-1 text-sm text-muted-foreground">{meta.author}</p>
              <div className="mt-3 flex flex-wrap items-center gap-2">
                {meta.category && <Badge variant="outline">{meta.category}</Badge>}
                <Badge variant={meta.subscribed ? 'default' : 'secondary'}>
                  {meta.subscribed ? '已订阅' : '未订阅'}
                </Badge>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">
            剧集列表
            <span className="ml-2 text-sm font-normal text-muted-foreground">({episodes.length} 集)</span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {episodes.length > 0 ? (
            <div className="space-y-3">
              {episodes.map((ep) => (
                <Link
                  key={ep.id}
                  href={`/podcasts/${id}/${ep.id}`}
                  className="block rounded-lg border p-4 transition-colors hover:bg-muted/50"
                >
                  <h3 className="font-medium leading-snug">{ep.title}</h3>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                    {ep.published_at && (
                      <span className="flex items-center gap-1"><Clock className="h-3 w-3" />{formatDate(ep.published_at)}</span>
                    )}
                    {ep.duration > 0 && <span>{formatDuration(ep.duration)}</span>}
                    {ep.summary_status === 'done' && <Badge variant="secondary" className="text-xs">已摘要</Badge>}
                  </div>
                  {ep.tags.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1">
                      {ep.tags.map((t) => <Badge key={t} variant="outline" className="text-xs">{t}</Badge>)}
                    </div>
                  )}
                </Link>
              ))}
            </div>
          ) : (
            <p className="py-10 text-center text-sm text-muted-foreground">暂无剧集</p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
