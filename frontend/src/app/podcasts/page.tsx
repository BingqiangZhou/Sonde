import Image from 'next/image';
import Link from 'next/link';
import { Trophy } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { loadRankings } from '@/lib/loaders';
import type { RankingsData } from '@/types';

export default async function PodcastsPage() {
  let data: RankingsData | null = null;
  try {
    data = await loadRankings();
  } catch {
    data = null;
  }
  const podcasts = data?.podcasts ?? [];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Trophy className="h-6 w-6 text-yellow-500" />
        <div>
          <h1 className="text-2xl font-bold tracking-tight">播客排行榜</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            共 {podcasts.length} 个播客
            {data?.fetched_at && ` · 更新于 ${new Date(data.fetched_at).toLocaleDateString('zh-CN')}`}
          </p>
        </div>
      </div>

      {podcasts.length > 0 ? (
        <div className="rounded-xl border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-16 text-center">排名</TableHead>
                <TableHead className="w-12" />
                <TableHead>名称</TableHead>
                <TableHead className="hidden md:table-cell">作者</TableHead>
                <TableHead className="hidden sm:table-cell">分类</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {podcasts.map((p) => {
                const rank = p.rank;
                const rankDisplay = rank <= 3 ? (
                  <span className={`inline-flex h-7 w-7 items-center justify-center rounded-full text-sm font-bold ${
                    rank === 1 ? 'bg-yellow-500/15 text-yellow-600'
                      : rank === 2 ? 'bg-gray-400/15 text-gray-500'
                      : 'bg-orange-400/15 text-orange-600'
                  }`}>{rank}</span>
                ) : (
                  <span className="text-sm tabular-nums text-muted-foreground">{rank}</span>
                );
                return (
                  <TableRow key={p.id} className="cursor-pointer">
                    <TableCell className="text-center">{rankDisplay}</TableCell>
                    <TableCell>
                      {p.logo_url ? (
                        <Image src={p.logo_url} alt={p.name} width={40} height={40} className="h-10 w-10 rounded object-cover" />
                      ) : (
                        <div className="flex h-10 w-10 items-center justify-center rounded bg-muted text-xs font-medium">{p.name.charAt(0)}</div>
                      )}
                    </TableCell>
                    <TableCell>
                      <Link href={`/podcasts/${p.id}`} className="font-medium line-clamp-1 hover:text-primary">{p.name}</Link>
                    </TableCell>
                    <TableCell className="hidden md:table-cell text-muted-foreground line-clamp-1">{p.author}</TableCell>
                    <TableCell className="hidden sm:table-cell">
                      {p.category ? <Badge variant="secondary">{p.category}</Badge> : <span className="text-muted-foreground">-</span>}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center rounded-xl border bg-card py-20">
          <p className="text-sm text-muted-foreground">暂无排行榜数据</p>
          <p className="mt-1 text-xs text-muted-foreground/60">运行 fetch-rankings skill 后显示</p>
        </div>
      )}
    </div>
  );
}
