"use client";

import { use, useState, useCallback, useEffect } from "react";
import Image from "next/image";
import Link from "next/link";
import {
  ArrowLeft,
  Rss,
  Loader2,
  CheckCircle2,
  XCircle,
  Clock,
  FileText,
  PlayCircle,
  Tag,
} from "lucide-react";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  useSubscriptions,
  useRssFeed,
  useSaveNote,
  useTaskProgress,
  useKnowledgeNotes,
} from "@/lib/queries";
import type { RssEpisode, Subscription, SaveNoteResponse, Note } from "@/types";

/** Task tracking state for a single episode */
interface EpisodeTask {
  episodeLink: string;
  taskId: string;
}

function formatDate(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString("zh-CN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
  } catch {
    return dateStr;
  }
}

function formatDuration(seconds: number): string {
  if (!seconds || seconds <= 0) return "未知";
  const mins = Math.floor(seconds / 60);
  const hrs = Math.floor(mins / 60);
  const remainMins = mins % 60;
  if (hrs > 0) {
    return `${hrs}小时${remainMins > 0 ? ` ${remainMins}分钟` : ""}`;
  }
  return `${mins}分钟`;
}

/** Renders processing status for a single episode task */
function TaskStatusBadge({ taskId }: { taskId: string }) {
  const { data, isLoading } = useTaskProgress(taskId);

  if (isLoading || !data) {
    return (
      <Badge variant="secondary" className="gap-1">
        <Loader2 className="h-3 w-3 animate-spin" />
        查询中
      </Badge>
    );
  }

  switch (data.status) {
    case "success":
      return (
        <Badge variant="default" className="gap-1 bg-green-600">
          <CheckCircle2 className="h-3 w-3" />
          完成
        </Badge>
      );
    case "failed":
      return (
        <Badge variant="destructive" className="gap-1">
          <XCircle className="h-3 w-3" />
          失败
        </Badge>
      );
    case "processing":
      return (
        <Badge variant="secondary" className="gap-1">
          <Loader2 className="h-3 w-3 animate-spin" />
          处理中
        </Badge>
      );
    default:
      return (
        <Badge variant="outline" className="gap-1">
          <Clock className="h-3 w-3" />
          等待中
        </Badge>
      );
  }
}

export default function PodcastDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);

  // Subscription data from localStorage
  const { data: subscriptionMap, isLoading: subLoading } = useSubscriptions();
  const subscription: Subscription | null =
    subscriptionMap?.[id] ?? null;

  // RSS feed parsing
  const rssFeedMut = useRssFeed();
  const [episodes, setEpisodes] = useState<RssEpisode[]>([]);
  const [feedParsed, setFeedParsed] = useState(false);

  // Note saving + task tracking
  const saveNoteMut = useSaveNote();
  const [episodeTasks, setEpisodeTasks] = useState<EpisodeTask[]>([]);

  // Knowledge notes for this podcast's topic
  const topicId = subscription?.topicId ?? "";
  const { data: knowledgeData, isLoading: notesLoading } = useKnowledgeNotes(
    topicId,
    1
  );

  // Parse RSS feed
  const handleParseRss = useCallback(() => {
    if (!subscription?.rssUrl) return;
    rssFeedMut.mutate(subscription.rssUrl, {
      onSuccess: (data) => {
        setEpisodes(data?.episodes ?? []);
        setFeedParsed(true);
      },
    });
  }, [subscription?.rssUrl]);

  // Process a single episode: save as note to knowledge base
  const handleProcessEpisode = useCallback(
    (episode: RssEpisode) => {
      if (!topicId) return;
      saveNoteMut.mutate(
        {
          note_type: "link",
          link_url: episode.link,
          topic_id: topicId,
        },
        {
          onSuccess: (resp: SaveNoteResponse) => {
            // Track all returned tasks
            const tasks = resp?.tasks ?? [];
            for (const t of tasks) {
              if (t.task_id) {
                setEpisodeTasks((prev) => [
                  ...prev,
                  { episodeLink: episode.link, taskId: t.task_id },
                ]);
              }
            }
          },
        }
      );
    },
    [topicId]
  );

  // Loading subscription data
  if (subLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-4 w-32" />
        <Skeleton className="h-40 w-full" />
      </div>
    );
  }

  // Not subscribed
  if (!subscription) {
    return (
      <div className="py-20 text-center">
        <p className="text-muted-foreground">未找到该播客的订阅信息</p>
        <Link
          href="/podcasts"
          className="mt-4 inline-flex items-center gap-1 text-sm text-primary hover:underline"
        >
          <ArrowLeft className="h-4 w-4" />
          返回播客列表
        </Link>
      </div>
    );
  }

  // Check if an episode already has a task
  const hasTask = (link: string) =>
    episodeTasks.some((t) => t.episodeLink === link);

  return (
    <div className="space-y-6">
      {/* Back link */}
      <Link
        href="/podcasts"
        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className="h-4 w-4" />
        返回播客列表
      </Link>

      {/* Podcast Header */}
      <Card>
        <CardContent className="p-6">
          <div className="flex flex-col gap-6 sm:flex-row sm:items-start">
            {/* Logo */}
            <div className="relative h-24 w-24 flex-shrink-0 overflow-hidden rounded-xl bg-muted">
              {subscription.logoUrl ? (
                <Image
                  src={subscription.logoUrl}
                  alt={subscription.podcastName}
                  fill
                  className="object-cover"
                  sizes="96px"
                />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-3xl font-bold text-muted-foreground">
                  {subscription.podcastName.charAt(0)}
                </div>
              )}
            </div>

            {/* Info */}
            <div className="min-w-0 flex-1">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h1 className="text-xl font-bold">
                    {subscription.podcastName}
                  </h1>
                  <p className="mt-1 text-sm text-muted-foreground">
                    {subscription.category}
                  </p>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleParseRss}
                  disabled={rssFeedMut.isPending || !subscription.rssUrl}
                >
                  {rssFeedMut.isPending ? (
                    <>
                      <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" />
                      解析中...
                    </>
                  ) : (
                    <>
                      <Rss className="mr-1.5 h-3.5 w-3.5" />
                      解析 RSS
                    </>
                  )}
                </Button>
              </div>

              <div className="mt-3 flex flex-wrap items-center gap-2">
                {subscription.category && (
                  <Badge variant="outline">{subscription.category}</Badge>
                )}
                {subscription.rssUrl && (
                  <span className="text-xs text-muted-foreground truncate max-w-[300px]">
                    RSS: {subscription.rssUrl}
                  </span>
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* RSS Feed Error */}
      {rssFeedMut.isError && (
        <Card className="border-destructive">
          <CardContent className="p-4">
            <p className="text-sm text-destructive">
              RSS 解析失败: {(rssFeedMut.error as Error)?.message ?? "未知错误"}
            </p>
          </CardContent>
        </Card>
      )}

      {/* Episodes from RSS */}
      {feedParsed && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              剧集列表
              <span className="ml-2 text-sm font-normal text-muted-foreground">
                ({episodes.length} 集)
              </span>
            </CardTitle>
          </CardHeader>
          <CardContent>
            {episodes.length > 0 ? (
              <div className="space-y-3">
                {episodes.map((ep, idx) => (
                  <div
                    key={ep.link ?? idx}
                    className="flex items-start justify-between gap-4 rounded-lg border p-4"
                  >
                    <div className="min-w-0 flex-1">
                      <h3 className="font-medium leading-snug">{ep.title}</h3>
                      <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                        {ep.published_at && (
                          <span className="flex items-center gap-1">
                            <Clock className="h-3 w-3" />
                            {formatDate(ep.published_at)}
                          </span>
                        )}
                        {ep.duration > 0 && <span>{formatDuration(ep.duration)}</span>}
                      </div>
                      {/* Show task status if processing */}
                      {hasTask(ep.link) && (
                        <div className="mt-2">
                          {episodeTasks
                            .filter((t) => t.episodeLink === ep.link)
                            .map((t) => (
                              <TaskStatusBadge key={t.taskId} taskId={t.taskId} />
                            ))}
                        </div>
                      )}
                    </div>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleProcessEpisode(ep)}
                      disabled={
                        saveNoteMut.isPending || hasTask(ep.link) || !topicId
                      }
                    >
                      {saveNoteMut.isPending ? (
                        <Loader2 className="mr-1 h-3.5 w-3.5 animate-spin" />
                      ) : (
                        <PlayCircle className="mr-1 h-3.5 w-3.5" />
                      )}
                      处理
                    </Button>
                  </div>
                ))}
              </div>
            ) : (
              <p className="py-10 text-center text-sm text-muted-foreground">
                RSS 订阅中暂无剧集
              </p>
            )}
          </CardContent>
        </Card>
      )}

      {/* Knowledge Base Notes */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">
            <FileText className="mr-2 inline h-4 w-4" />
            知识库笔记
            {knowledgeData?.notes && (
              <span className="ml-2 text-sm font-normal text-muted-foreground">
                ({knowledgeData.notes.length} 条)
              </span>
            )}
          </CardTitle>
        </CardHeader>
        <CardContent>
          {notesLoading ? (
            <div className="space-y-3">
              {[1, 2, 3].map((i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : knowledgeData?.notes && knowledgeData.notes.length > 0 ? (
            <div className="space-y-2">
              {knowledgeData.notes.map((note: Note) => (
                <Link
                  key={note.note_id}
                  href={`/episodes/${note.note_id}`}
                  className="block rounded-lg border p-4 transition-colors hover:bg-muted/50"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0 flex-1">
                      <h3 className="font-medium leading-snug">{note.title}</h3>
                      <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                        <span>{formatDate(note.created_at)}</span>
                        {note.tags && note.tags.length > 0 && (
                          <span className="flex items-center gap-1">
                            <Tag className="h-3 w-3" />
                            {note.tags.map((t) => t.name).join(", ")}
                          </span>
                        )}
                      </div>
                    </div>
                    <Badge variant="secondary" className="shrink-0">
                      {note.note_type}
                    </Badge>
                  </div>
                </Link>
              ))}
            </div>
          ) : (
            <p className="py-10 text-center text-sm text-muted-foreground">
              知识库暂无笔记，解析 RSS 后处理剧集即可添加
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
