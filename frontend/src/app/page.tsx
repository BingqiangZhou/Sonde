import Link from 'next/link';
import Image from 'next/image';
import { Podcast, FileText, ArrowRight } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { loadIndex } from '@/lib/loaders';
import type { DataIndex } from '@/types';

export default async function DashboardPage() {
  let index: DataIndex | null = null;
  try {
    index = await loadIndex();
  } catch {
    index = null;
  }

  const subscriptions = index?.subscribed_podcasts ?? [];
  const recent = index?.recent_summarized_episodes ?? [];

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight">PodcastInsight</h1>
        <Link href="/podcasts" className="inline-flex items-center gap-1.5 text-sm text-primary hover:underline">
          <Podcast className="h-4 w-4" />
          发现播客
        </Link>
      </div>

      <section className="space-y-4">
        <h2 className="flex items-center gap-2 text-lg font-semibold">
          <Podcast className="h-5 w-5 text-primary" />
          已订阅播客
        </h2>
        {subscriptions.length > 0 ? (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {subscriptions.map((sub) => (
              <Link key={sub.id} href={`/podcasts/${sub.id}`} className="group block">
                <Card className="overflow-hidden transition-all duration-200 hover:border-primary/20 hover:shadow-md">
                  <CardContent className="p-4">
                    <div className="flex items-start gap-3">
                      <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
                        {sub.logo_url ? (
                          <Image src={sub.logo_url} alt={sub.name} fill className="object-cover" sizes="56px" />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-lg font-bold text-muted-foreground">
                            {sub.name.charAt(0)}
                          </div>
                        )}
                      </div>
                      <div className="min-w-0 flex-1">
                        <h3 className="truncate text-sm font-semibold leading-tight group-hover:text-primary">
                          {sub.name}
                        </h3>
                        {sub.category && <p className="mt-1 truncate text-xs text-muted-foreground">{sub.category}</p>}
                        <p className="mt-1 text-xs text-muted-foreground">{sub.episode_count} 集</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </Link>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-16">
            <Podcast className="h-10 w-10 text-muted-foreground/40" />
            <p className="mt-3 text-sm text-muted-foreground">还没有订阅任何播客</p>
            <p className="mt-1 text-xs text-muted-foreground/60">通过 skills 配置 data/podcasts/ 后显示</p>
          </div>
        )}
      </section>

      <section className="space-y-4">
        <h2 className="flex items-center gap-2 text-lg font-semibold">
          <FileText className="h-5 w-5 text-primary" />
          最近摘要
        </h2>
        {recent.length > 0 ? (
          <div className="divide-y rounded-lg border">
            {recent.map((ep) => (
              <Link
                key={ep.episode_id}
                href={`/podcasts/${ep.podcast_id}/${ep.episode_id}`}
                className="group flex items-center gap-4 px-4 py-3 transition-colors hover:bg-muted/30"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium group-hover:text-primary">{ep.title || '无标题'}</p>
                  <p className="mt-1 text-xs text-muted-foreground">
                    {ep.podcast_name} · {ep.published_at ? new Date(ep.published_at).toLocaleDateString('zh-CN') : ''}
                  </p>
                </div>
                <ArrowRight className="h-4 w-4 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
              </Link>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-16">
            <FileText className="h-10 w-10 text-muted-foreground/40" />
            <p className="mt-3 text-sm text-muted-foreground">暂无摘要</p>
            <p className="mt-1 text-xs text-muted-foreground/60">运行 summarize skill 后显示</p>
          </div>
        )}
      </section>
    </div>
  );
}
