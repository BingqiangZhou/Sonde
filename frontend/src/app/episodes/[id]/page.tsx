'use client';

import { use, useState } from 'react';
import Link from 'next/link';
import { ArrowLeft, Sparkles, ChevronDown, ChevronUp, Calendar, Clock, Tag } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { useNoteDetail } from '@/lib/queries';
import type { NoteDetail } from '@/types';

function formatDate(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    return d.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return dateStr;
  }
}

function NoteDetailLoading() {
  return (
    <div className="space-y-6">
      <Skeleton className="h-4 w-24" />
      <Skeleton className="h-8 w-3/4" />
      <Skeleton className="h-32 w-full rounded-xl" />
      <div className="space-y-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} className="h-4 w-full" />
        ))}
      </div>
      <div className="flex gap-2">
        <Skeleton className="h-6 w-16" />
        <Skeleton className="h-6 w-16" />
        <Skeleton className="h-6 w-16" />
      </div>
    </div>
  );
}

function NoteDetailError({ message }: { message: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-20">
      <p className="text-sm text-destructive">{message}</p>
      <Button variant="outline" size="sm" className="mt-4" asChild>
        <Link href="/">返回首页</Link>
      </Button>
    </div>
  );
}

function NoteDetailContent({ note }: { note: NoteDetail }) {
  const [showOriginal, setShowOriginal] = useState(false);

  const hasExcerpt = note.web_page?.excerpt && note.web_page.excerpt.trim().length > 0;
  const hasOriginalContent = note.web_page?.content && note.web_page.content.trim().length > 0;
  const hasTags = note.tags && note.tags.length > 0;

  return (
    <div className="space-y-6">
      {/* Back navigation */}
      <Link
        href="/"
        className="group inline-flex items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-primary"
      >
        <ArrowLeft className="h-3.5 w-3.5 transition-transform group-hover:-translate-x-0.5" />
        <span>返回</span>
      </Link>

      {/* Title */}
      <div className="space-y-4">
        <h1 className="text-2xl font-semibold leading-snug tracking-tight sm:text-3xl">
          {note.title || '无标题'}
        </h1>

        {/* Timestamps */}
        <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-sm text-muted-foreground">
          {note.created_at && (
            <span className="inline-flex items-center gap-1">
              <Calendar className="h-3.5 w-3.5" />
              创建: {formatDate(note.created_at)}
            </span>
          )}
          {note.updated_at && note.updated_at !== note.created_at && (
            <span className="inline-flex items-center gap-1">
              <Clock className="h-3.5 w-3.5" />
              更新: {formatDate(note.updated_at)}
            </span>
          )}
        </div>
      </div>

      {/* AI Summary Card */}
      {hasExcerpt && (
        <Card className="border-primary/20 bg-primary/5">
          <CardContent className="p-5">
            <div className="mb-2 flex items-center gap-2 text-sm font-medium text-primary">
              <Sparkles className="h-4 w-4" />
              AI 摘要
            </div>
            <p className="text-sm leading-relaxed text-foreground/90">
              {note.web_page!.excerpt}
            </p>
          </CardContent>
        </Card>
      )}

      {/* Note Content */}
      {note.content && (
        <div className="rounded-xl border bg-card p-5">
          <pre className="whitespace-pre-wrap break-words text-sm leading-relaxed font-body">
            {note.content}
          </pre>
        </div>
      )}

      {/* Original Content Collapsible */}
      {hasOriginalContent && (
        <div className="space-y-2">
          <Button
            variant="ghost"
            size="sm"
            className="gap-1.5 text-muted-foreground"
            onClick={() => setShowOriginal((v) => !v)}
          >
            {showOriginal ? (
              <ChevronUp className="h-4 w-4" />
            ) : (
              <ChevronDown className="h-4 w-4" />
            )}
            {showOriginal ? '收起原文' : '展开原文'}
          </Button>
          {showOriginal && (
            <div className="rounded-xl border bg-muted/30 p-5">
              <pre className="whitespace-pre-wrap break-words text-sm leading-relaxed font-body text-muted-foreground">
                {note.web_page!.content}
              </pre>
            </div>
          )}
        </div>
      )}

      {/* Tags */}
      {hasTags && (
        <div className="space-y-2">
          <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
            <Tag className="h-3.5 w-3.5" />
            标签
          </div>
          <div className="flex flex-wrap gap-2">
            {note.tags.map((tag) => (
              <Badge key={tag.id} variant="secondary">
                {tag.name}
              </Badge>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default function EpisodeDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const { data: note, isLoading, error } = useNoteDetail(id);

  if (isLoading) {
    return <NoteDetailLoading />;
  }

  if (error) {
    return <NoteDetailError message={error.message ?? '加载失败'} />;
  }

  if (!note) {
    return <NoteDetailError message="笔记未找到" />;
  }

  return <NoteDetailContent note={note} />;
}
