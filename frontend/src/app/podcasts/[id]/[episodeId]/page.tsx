import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Sparkles, Tag } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  loadEpisodeContent, loadPodcastMeta, listPodcastIds, listEpisodeIds,
} from '@/lib/loaders';
import { renderMarkdown } from '@/lib/markdown';

export async function generateStaticParams() {
  const podcastIds = await listPodcastIds();
  const params: { id: string; episodeId: string }[] = [];
  for (const pid of podcastIds) {
    const epIds = await listEpisodeIds(pid);
    for (const eid of epIds) params.push({ id: pid, episodeId: eid });
  }
  return params;
}

export default async function EpisodeDetailPage({
  params,
}: {
  params: Promise<{ id: string; episodeId: string }>;
}) {
  const { id, episodeId } = await params;
  const content = await loadEpisodeContent(id, episodeId);
  const meta = await loadPodcastMeta(id);
  if (!content || !meta) notFound();

  return (
    <div className="space-y-6">
      <Link href={`/podcasts/${id}`} className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary">
        <ArrowLeft className="h-3.5 w-3.5" />
        返回 {meta.name}
      </Link>

      <div className="space-y-4">
        <h1 className="text-2xl font-semibold leading-snug tracking-tight">{content.frontmatter.title || '无标题'}</h1>
        <p className="text-sm text-muted-foreground">{meta.name}</p>
      </div>

      {content.summary && (
        <Card className="border-primary/20 bg-primary/5">
          <CardContent className="p-5">
            <div className="mb-2 flex items-center gap-2 text-sm font-medium text-primary">
              <Sparkles className="h-4 w-4" />
              AI 摘要
            </div>
            <div className="prose prose-sm dark:prose-invert max-w-none text-foreground/90" dangerouslySetInnerHTML={{ __html: renderMarkdown(content.summary) }} />
          </CardContent>
        </Card>
      )}

      {content.tags.length > 0 && (
        <div className="space-y-2">
          <div className="flex items-center gap-1.5 text-sm text-muted-foreground"><Tag className="h-3.5 w-3.5" />标签</div>
          <div className="flex flex-wrap gap-2">
            {content.tags.map((t) => <Badge key={t} variant="secondary">{t}</Badge>)}
          </div>
        </div>
      )}

      {content.body && (
        <div className="rounded-xl border bg-card p-5">
          <article className="prose prose-sm dark:prose-invert max-w-none" dangerouslySetInnerHTML={{ __html: renderMarkdown(content.body) }} />
        </div>
      )}
    </div>
  );
}
