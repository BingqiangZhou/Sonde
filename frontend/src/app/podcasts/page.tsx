'use client';

import { useState, useMemo, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { Search, Trophy, ChevronLeft, ChevronRight, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { useRankings, useSubscriptions, useSubscribe, useUnsubscribe, useCreateKnowledgeBase } from '@/lib/queries';
import type { XyzrankPodcast } from '@/types';
import { toast } from 'sonner';

const PAGE_SIZE = 50;

export default function PodcastsPage() {
  const router = useRouter();
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('全部');

  const offset = (page - 1) * PAGE_SIZE;
  const { data, isLoading } = useRankings(offset, PAGE_SIZE);
  const { data: subs } = useSubscriptions();

  const subscribeMut = useSubscribe();
  const unsubscribeMut = useUnsubscribe();
  const createKbMut = useCreateKnowledgeBase();

  const subscribedIds = useMemo(() => {
    return new Set(Object.keys(subs ?? {}));
  }, [subs]);

  // Derive unique categories from loaded data
  const categories = useMemo(() => {
    if (!data?.podcasts) return ['全部'];
    const cats = new Set(data.podcasts.map((p) => p.category).filter(Boolean));
    return ['全部', ...Array.from(cats).sort()];
  }, [data]);

  // Filter podcasts by search text and category
  const filteredPodcasts = useMemo(() => {
    let list = data?.podcasts ?? [];
    if (search) {
      const q = search.toLowerCase();
      list = list.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          p.author.toLowerCase().includes(q)
      );
    }
    if (category && category !== '全部') {
      list = list.filter((p) => p.category === category);
    }
    return list;
  }, [data, search, category]);

  const totalPages = Math.ceil((data?.total ?? 0) / PAGE_SIZE);

  const handleSubscribe = useCallback(
    async (podcast: XyzrankPodcast) => {
      try {
        const kbResult = await createKbMut.mutateAsync({
          name: podcast.name,
          description: `${podcast.name} - ${podcast.category}`,
        });
        subscribeMut.mutate(
          {
            xyzrankId: podcast.id,
            topicId: kbResult?.topic_id ?? '',
            podcastName: podcast.name,
            rssUrl: podcast.rss_feed_url,
            logoUrl: podcast.logo_url,
            category: podcast.category,
          },
          {
            onSuccess: () => toast.success(`已订阅「${podcast.name}」`),
            onError: (err) => toast.error(`订阅失败: ${err.message}`),
          }
        );
      } catch (err: any) {
        toast.error(`创建知识库失败: ${err.message}`);
      }
    },
    [createKbMut, subscribeMut]
  );

  const handleUnsubscribe = useCallback(
    (podcast: XyzrankPodcast) => {
      unsubscribeMut.mutate(podcast.id, {
        onSuccess: () => toast.success(`已取消订阅「${podcast.name}」`),
        onError: (err) => toast.error(`取消订阅失败: ${err.message}`),
      });
    },
    [unsubscribeMut]
  );

  const isMutating = subscribeMut.isPending || unsubscribeMut.isPending || createKbMut.isPending;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Trophy className="h-6 w-6 text-yellow-500" />
        <div>
          <h1 className="text-2xl font-bold tracking-tight">播客排行榜</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            共 {data?.total ?? '-'} 个播客
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3 rounded-xl border bg-card p-3">
        <div className="relative flex items-center w-full max-w-xs">
          <Search className="absolute left-3 h-4 w-4 text-muted-foreground" />
          <Input
            type="text"
            placeholder="搜索播客名称或作者..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <Select value={category} onValueChange={setCategory}>
          <SelectTrigger className="w-[140px] h-9">
            <SelectValue placeholder="分类筛选" />
          </SelectTrigger>
          <SelectContent>
            {categories.map((cat) => (
              <SelectItem key={cat} value={cat}>
                {cat}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <span className="ml-auto text-sm tabular-nums text-muted-foreground">
          显示 {filteredPodcasts.length} 个结果
        </span>
      </div>

      {/* Rankings Table */}
      {isLoading ? (
        <div className="rounded-xl border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-16 text-center">排名</TableHead>
                <TableHead className="w-12" />
                <TableHead>名称</TableHead>
                <TableHead className="hidden md:table-cell">作者</TableHead>
                <TableHead className="hidden sm:table-cell">分类</TableHead>
                <TableHead className="w-28 text-center">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {Array.from({ length: 10 }).map((_, i) => (
                <TableRow key={i}>
                  <TableCell className="text-center">
                    <Skeleton className="mx-auto h-5 w-8" />
                  </TableCell>
                  <TableCell>
                    <Skeleton className="h-10 w-10 rounded" />
                  </TableCell>
                  <TableCell>
                    <Skeleton className="h-4 w-36" />
                  </TableCell>
                  <TableCell className="hidden md:table-cell">
                    <Skeleton className="h-4 w-24" />
                  </TableCell>
                  <TableCell className="hidden sm:table-cell">
                    <Skeleton className="h-5 w-16 rounded" />
                  </TableCell>
                  <TableCell className="text-center">
                    <Skeleton className="mx-auto h-8 w-20 rounded" />
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      ) : filteredPodcasts.length > 0 ? (
        <div className="rounded-xl border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-16 text-center">排名</TableHead>
                <TableHead className="w-12" />
                <TableHead>名称</TableHead>
                <TableHead className="hidden md:table-cell">作者</TableHead>
                <TableHead className="hidden sm:table-cell">分类</TableHead>
                <TableHead className="w-28 text-center">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredPodcasts.map((podcast) => {
                const isSubscribed = subscribedIds.has(podcast.id);
                const rank = podcast.rank;
                const rankDisplay =
                  rank <= 3 ? (
                    <span
                      className={`inline-flex h-7 w-7 items-center justify-center rounded-full text-sm font-bold ${
                        rank === 1
                          ? 'bg-yellow-500/15 text-yellow-600'
                          : rank === 2
                            ? 'bg-gray-400/15 text-gray-500'
                            : 'bg-orange-400/15 text-orange-600'
                      }`}
                    >
                      {rank}
                    </span>
                  ) : (
                    <span className="text-sm tabular-nums text-muted-foreground">
                      {rank}
                    </span>
                  );

                return (
                  <TableRow
                    key={podcast.id}
                    className={`cursor-pointer ${isSubscribed ? 'bg-primary/5' : ''}`}
                    onClick={() => router.push(`/podcasts/${podcast.id}`)}
                  >
                    <TableCell className="text-center">{rankDisplay}</TableCell>
                    <TableCell>
                      {podcast.logo_url ? (
                        <img
                          src={podcast.logo_url}
                          alt={podcast.name}
                          className="h-10 w-10 rounded object-cover"
                          loading="lazy"
                        />
                      ) : (
                        <div className="flex h-10 w-10 items-center justify-center rounded bg-muted text-xs font-medium">
                          {podcast.name.charAt(0)}
                        </div>
                      )}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <span className="font-medium line-clamp-1">{podcast.name}</span>
                        {isSubscribed && (
                          <Badge variant="default" className="shrink-0 text-[10px] px-1.5 py-0">
                            已订阅
                          </Badge>
                        )}
                      </div>
                    </TableCell>
                    <TableCell className="hidden md:table-cell text-muted-foreground line-clamp-1">
                      {podcast.author}
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">
                      {podcast.category ? (
                        <Badge variant="secondary">{podcast.category}</Badge>
                      ) : (
                        <span className="text-muted-foreground">-</span>
                      )}
                    </TableCell>
                    <TableCell className="text-center">
                      {isSubscribed ? (
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleUnsubscribe(podcast);
                          }}
                          disabled={isMutating}
                        >
                          {unsubscribeMut.isPending ? (
                            <Loader2 className="mr-1 h-3 w-3 animate-spin" />
                          ) : null}
                          取消订阅
                        </Button>
                      ) : (
                        <Button
                          variant="default"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleSubscribe(podcast);
                          }}
                          disabled={isMutating}
                        >
                          {createKbMut.isPending || subscribeMut.isPending ? (
                            <Loader2 className="mr-1 h-3 w-3 animate-spin" />
                          ) : null}
                          订阅
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center rounded-xl border bg-card py-20">
          <Search className="h-12 w-12 text-muted-foreground/30" />
          <p className="mt-4 text-sm text-muted-foreground">未找到匹配的播客</p>
          {(search || category !== '全部') && (
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => {
                setSearch('');
                setCategory('全部');
              }}
            >
              清除筛选条件
            </Button>
          )}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1}
          >
            <ChevronLeft className="mr-1 h-4 w-4" />
            上一页
          </Button>
          <span className="min-w-[80px] text-center text-sm tabular-nums text-muted-foreground">
            {page} / {totalPages}
          </span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
            disabled={page >= totalPages}
          >
            下一页
            <ChevronRight className="ml-1 h-4 w-4" />
          </Button>
        </div>
      )}
    </div>
  );
}
