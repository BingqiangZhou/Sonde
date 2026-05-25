"use client";

import { Suspense, useState, useCallback } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import { Search, FileText, Database } from "lucide-react";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
} from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import {
  useGlobalRecall,
  useKnowledgeRecall,
  useSubscriptions,
} from "@/lib/queries";
import type { RecallResult } from "@/types";

export default function SearchPage() {
  return (
    <Suspense fallback={<SearchPageSkeleton />}>
      <SearchContent />
    </Suspense>
  );
}

function SearchPageSkeleton() {
  return (
    <div className="space-y-6">
      <div>
        <Skeleton className="h-7 w-28" />
        <Skeleton className="mt-1 h-4 w-44" />
      </div>
      <Skeleton className="h-11 w-full" />
      <div className="space-y-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <ResultCardSkeleton key={i} />
        ))}
      </div>
    </div>
  );
}

function ResultCardSkeleton() {
  return (
    <Card>
      <CardHeader>
        <Skeleton className="h-5 w-2/3" />
        <Skeleton className="h-4 w-32" />
      </CardHeader>
      <CardContent>
        <Skeleton className="h-4 w-full" />
        <Skeleton className="mt-2 h-4 w-4/5" />
      </CardContent>
    </Card>
  );
}

function SearchContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const initialQuery = searchParams.get("q") ?? "";

  const [inputValue, setInputValue] = useState(initialQuery);
  const [selectedTopicId, setSelectedTopicId] = useState<string>("all");

  const { data: subscriptions } = useSubscriptions();
  const subs = subscriptions ? Object.values(subscriptions) : [];

  const query = initialQuery;
  const isGlobalSearch = selectedTopicId === "all";

  const globalRecall = useGlobalRecall(query);
  const knowledgeRecall = useKnowledgeRecall(
    isGlobalSearch ? "" : selectedTopicId,
    query
  );

  const results = isGlobalSearch
    ? globalRecall.data?.results ?? []
    : knowledgeRecall.data?.results ?? [];

  const isLoading =
    query.length > 0 &&
    (isGlobalSearch ? globalRecall.isLoading : knowledgeRecall.isLoading);

  const handleSearch = useCallback(() => {
    const trimmed = inputValue.trim();
    if (trimmed) {
      router.push(`/search?q=${encodeURIComponent(trimmed)}`);
    }
  }, [inputValue, router]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "Enter") {
        handleSearch();
      }
    },
    [handleSearch]
  );

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-bold tracking-tight">语义搜索</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          在知识库中进行智能语义检索
        </p>
      </div>

      {/* Search Controls */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            className="pl-9 h-11"
            placeholder="输入关键词搜索..."
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyDown}
          />
        </div>
        <Select value={selectedTopicId} onValueChange={setSelectedTopicId}>
          <SelectTrigger className="w-full sm:w-[220px] h-11">
            <Database className="mr-2 h-4 w-4 text-muted-foreground" />
            <SelectValue placeholder="选择知识库" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">全部</SelectItem>
            {subs.map((sub) => (
              <SelectItem key={sub.topicId} value={sub.topicId}>
                {sub.podcastName}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Search Results */}
      {!query ? (
        <EmptyState
          icon={<Search className="h-12 w-12 text-muted-foreground/30" />}
          message="输入关键词开始搜索"
        />
      ) : isLoading ? (
        <div className="space-y-4">
          {Array.from({ length: 3 }).map((_, i) => (
            <ResultCardSkeleton key={i} />
          ))}
        </div>
      ) : results.length === 0 ? (
        <EmptyState
          icon={<FileText className="h-12 w-12 text-muted-foreground/30" />}
          message="未找到相关内容"
        />
      ) : (
        <div className="space-y-4">
          <p className="text-sm text-muted-foreground">
            找到 {results.length} 条结果
          </p>
          {results.map((result: RecallResult) => (
            <ResultCard key={result.note_id} result={result} />
          ))}
        </div>
      )}
    </div>
  );
}

function EmptyState({
  icon,
  message,
}: {
  icon: React.ReactNode;
  message: string;
}) {
  return (
    <div className="flex flex-col items-center justify-center py-20">
      {icon}
      <p className="mt-4 text-sm text-muted-foreground">{message}</p>
    </div>
  );
}

function ResultCard({ result }: { result: RecallResult }) {
  const snippet =
    result.content.length > 200
      ? result.content.slice(0, 200) + "..."
      : result.content;

  const date = result.created_at
    ? new Date(result.created_at).toLocaleDateString("zh-CN", {
        year: "numeric",
        month: "short",
        day: "numeric",
      })
    : "";

  return (
    <Link href={`/episodes/${result.note_id}`}>
      <Card className="transition-colors hover:bg-accent/50 cursor-pointer">
        <CardHeader>
          <div className="flex items-start justify-between gap-4">
            <CardTitle className="text-base line-clamp-1">
              {result.title || "无标题"}
            </CardTitle>
            <div className="flex shrink-0 items-center gap-2">
              {result.note_type && (
                <Badge variant="secondary" className="text-xs">
                  {result.note_type}
                </Badge>
              )}
            </div>
          </div>
          {date && (
            <CardDescription className="text-xs">{date}</CardDescription>
          )}
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground line-clamp-3">
            {snippet}
          </p>
        </CardContent>
      </Card>
    </Link>
  );
}
