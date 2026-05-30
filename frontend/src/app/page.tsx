'use client';

import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { Podcast, FileText, Search, ArrowRight, Plus } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { useSubscriptions, useNotes } from '@/lib/queries';
import type { Note, NoteTag } from '@/types';

export default function DashboardPage() {
  const router = useRouter();
  const [searchValue, setSearchValue] = useState('');
  const { data: subscriptionMap, isLoading: subsLoading } = useSubscriptions();
  const { data: notesData, isLoading: notesLoading } = useNotes();

  const subscriptions = subscriptionMap
    ? Object.values(subscriptionMap)
    : [];
  const notes = notesData?.notes ?? [];

  const handleSearchKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && searchValue.trim()) {
      router.push(`/search?q=${encodeURIComponent(searchValue.trim())}`);
    }
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight">PodcastInsight</h1>
        <Link href="/podcasts">
          <Button variant="outline" size="sm">
            <Podcast className="mr-1.5 h-4 w-4" />
            发现播客
          </Button>
        </Link>
      </div>

      {/* Search Bar */}
      <div className="relative flex items-center w-full max-w-xl">
        <Search className="absolute left-3 h-4 w-4 text-muted-foreground" />
        <Input
          type="text"
          placeholder="搜索播客、笔记..."
          value={searchValue}
          onChange={(e) => setSearchValue(e.target.value)}
          onKeyDown={handleSearchKeyDown}
          className="pl-9"
        />
      </div>

      {/* Subscribed Podcasts Section */}
      <section className="space-y-4">
        <h2 className="flex items-center gap-2 text-lg font-semibold">
          <Podcast className="h-5 w-5 text-primary" />
          已订阅播客
        </h2>

        {subsLoading ? (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Card key={i} className="overflow-hidden">
                <CardContent className="p-4">
                  <div className="flex items-start gap-3">
                    <Skeleton className="h-14 w-14 shrink-0 rounded-xl" />
                    <div className="flex-1 space-y-2">
                      <Skeleton className="h-4 w-3/4" />
                      <Skeleton className="h-3 w-1/2" />
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        ) : subscriptions.length > 0 ? (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {subscriptions.map((sub) => (
              <Link
                key={sub.xyzrankId}
                href={`/podcasts/${sub.xyzrankId}`}
                className="group block"
              >
                <Card className="overflow-hidden transition-all duration-200 hover:border-primary/20 hover:shadow-md">
                  <CardContent className="p-4">
                    <div className="flex items-start gap-3">
                      {/* Logo */}
                      <div className="relative h-14 w-14 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
                        {sub.logoUrl ? (
                          <Image
                            src={sub.logoUrl}
                            alt={sub.podcastName}
                            fill
                            className="object-cover transition-transform duration-300 group-hover:scale-110"
                            sizes="56px"
                          />
                        ) : (
                          <div className="flex h-full w-full items-center justify-center text-lg font-bold text-muted-foreground">
                            {sub.podcastName.charAt(0)}
                          </div>
                        )}
                      </div>

                      {/* Info */}
                      <div className="min-w-0 flex-1">
                        <h3 className="truncate text-sm font-semibold leading-tight group-hover:text-primary transition-colors">
                          {sub.podcastName}
                        </h3>
                        {sub.category && (
                          <p className="mt-1 truncate text-xs text-muted-foreground">
                            {sub.category}
                          </p>
                        )}
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
            <p className="mt-3 text-sm text-muted-foreground">
              还没有订阅任何播客
            </p>
            <Link href="/podcasts" className="mt-3">
              <Button variant="outline" size="sm">
                <Plus className="mr-1.5 h-3.5 w-3.5" />
                去发现并订阅
              </Button>
            </Link>
          </div>
        )}
      </section>

      {/* Recent Notes Section */}
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <h2 className="flex items-center gap-2 text-lg font-semibold">
            <FileText className="h-5 w-5 text-primary" />
            最近笔记
          </h2>
        </div>

        {notesLoading ? (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <Card key={i}>
                <CardContent className="p-4">
                  <div className="space-y-2">
                    <Skeleton className="h-4 w-2/3" />
                    <Skeleton className="h-3 w-1/3" />
                    <Skeleton className="h-5 w-20" />
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        ) : notes.length > 0 ? (
          <div className="divide-y rounded-lg border">
            {notes.map((note: Note) => (
              <Link
                key={note.note_id}
                href={`/episodes/${note.note_id}`}
                className="group flex items-center gap-4 px-4 py-3 transition-colors hover:bg-muted/30 first:rounded-t-lg last:rounded-b-lg"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium group-hover:text-primary transition-colors">
                    {note.title || '无标题'}
                  </p>
                  <div className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                    <span>
                      {note.created_at
                        ? new Date(note.created_at).toLocaleDateString('zh-CN')
                        : ''}
                    </span>
                  </div>
                </div>
                <div className="flex shrink-0 flex-wrap gap-1">
                  {(note.tags ?? []).map((tag: NoteTag) => (
                    <Badge key={tag.id} variant="secondary" className="text-xs">
                      {tag.name}
                    </Badge>
                  ))}
                </div>
                <ArrowRight className="h-4 w-4 shrink-0 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
              </Link>
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center rounded-lg border border-dashed py-16">
            <FileText className="h-10 w-10 text-muted-foreground/40" />
            <p className="mt-3 text-sm text-muted-foreground">暂无笔记</p>
          </div>
        )}
      </section>
    </div>
  );
}
