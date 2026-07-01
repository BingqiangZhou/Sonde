'use client';

import { useState, useMemo } from 'react';
import Link from 'next/link';
import { Search, FileText } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import type { SearchIndexEntry } from '@/types';

export function SearchClient({ entries }: { entries: SearchIndexEntry[] }) {
  const [q, setQ] = useState('');

  const results = useMemo(() => {
    const query = q.trim().toLowerCase();
    if (!query) return [];
    return entries.filter(
      (e) =>
        e.title.toLowerCase().includes(query) ||
        e.summary.toLowerCase().includes(query) ||
        e.podcast_name.toLowerCase().includes(query)
    );
  }, [q, entries]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">搜索</h1>
        <p className="mt-1 text-sm text-muted-foreground">在已生成摘要的剧集中搜索</p>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input className="pl-9 h-11" placeholder="输入关键词..." value={q} onChange={(e) => setQ(e.target.value)} />
      </div>

      {!q ? (
        <div className="flex flex-col items-center justify-center py-20">
          <Search className="h-12 w-12 text-muted-foreground/30" />
          <p className="mt-4 text-sm text-muted-foreground">输入关键词开始搜索</p>
        </div>
      ) : results.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20">
          <FileText className="h-12 w-12 text-muted-foreground/30" />
          <p className="mt-4 text-sm text-muted-foreground">未找到相关内容</p>
        </div>
      ) : (
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">找到 {results.length} 条结果</p>
          {results.map((r) => (
            <Link key={r.episode_id} href={`/podcasts/${r.podcast_id}/${r.episode_id}`}>
              <Card className="transition-colors hover:bg-accent/50">
                <CardHeader>
                  <CardTitle className="text-base line-clamp-1">{r.title || '无标题'}</CardTitle>
                  <CardDescription className="text-xs">{r.podcast_name}</CardDescription>
                </CardHeader>
                {r.summary && (
                  <CardContent>
                    <p className="text-sm text-muted-foreground line-clamp-3">{r.summary.slice(0, 200)}</p>
                  </CardContent>
                )}
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
