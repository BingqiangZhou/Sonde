"use client";

import { useState } from "react";
import { Loader2, Lightbulb, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useSummary, useEpisode, useSummarizeEpisode } from "@/lib/queries";
import { useSubmitSummaryFeedback } from "@/lib/api";
import { SummaryStatus } from "@/types";
import { cn } from "@/lib/utils";

interface SummaryCardProps {
  episodeId: string;
  isActive: boolean;
}

const TOPIC_COLORS = [
  "bg-chart-1/15 text-chart-1",
  "bg-chart-2/15 text-chart-2",
  "bg-chart-3/15 text-chart-3",
  "bg-chart-4/15 text-chart-4",
  "bg-chart-5/15 text-chart-5",
];

const HIGHLIGHT_COLORS = [
  "bg-chart-1",
  "bg-chart-2",
  "bg-chart-3",
  "bg-chart-4",
  "bg-chart-5",
];

function StarRating({
  rating,
  onRate,
  disabled,
}: {
  rating: number | null;
  onRate: (rating: number) => void;
  disabled?: boolean;
}) {
  const [hovered, setHovered] = useState<number | null>(null);

  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: 5 }, (_, i) => {
        const starIndex = i + 1;
        const filled = hovered !== null ? starIndex <= hovered : starIndex <= (rating ?? 0);
        return (
          <button
            key={i}
            type="button"
            disabled={disabled}
            onClick={() => onRate(starIndex)}
            onMouseEnter={() => setHovered(starIndex)}
            onMouseLeave={() => setHovered(null)}
            className={cn(
              "rounded-sm p-0.5 transition-colors",
              disabled
                ? "cursor-not-allowed opacity-50"
                : "cursor-pointer hover:bg-muted"
            )}
            aria-label={`Rate ${starIndex} star${starIndex > 1 ? "s" : ""}`}
          >
            <Star
              className={cn(
                "h-3.5 w-3.5 transition-colors",
                filled
                  ? "fill-yellow-400 text-yellow-400"
                  : "fill-transparent text-muted-foreground/40"
              )}
            />
          </button>
        );
      })}
    </div>
  );
}

export function SummaryCard({ episodeId, isActive }: SummaryCardProps) {
  // Get episode for status
  const { data: episode } = useEpisode(episodeId);

  // Fetch summary only when active and completed
  const { data: summary, isLoading, error } = useSummary(episodeId, {
    enabled:
      isActive &&
      (episode?.summary_status === SummaryStatus.Completed ||
        episode?.summary_status === SummaryStatus.Failed),
  });

  const summarizeMutation = useSummarizeEpisode();
  const feedbackMutation = useSubmitSummaryFeedback();

  const handleRate = (rating: number) => {
    if (!summary) return;
    feedbackMutation.mutate({ id: summary.id, data: { rating } });
  };

  // Loading state
  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
        <span className="ml-2 text-muted-foreground">加载 AI 总结...</span>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-6 text-center">
        <p className="text-destructive">加载 AI 总结失败</p>
        <p className="mt-1 text-sm text-muted-foreground">{(error as Error).message}</p>
      </div>
    );
  }

  // Not completed state
  if (episode?.summary_status !== SummaryStatus.Completed) {
    return (
      <div className="rounded-lg border border-dashed bg-muted/30 p-8 text-center">
        <p className="text-muted-foreground">
          {episode?.summary_status === SummaryStatus.Processing
            ? "AI 总结生成中..."
            : episode?.summary_status === SummaryStatus.Failed
            ? "总结生成失败"
            : "此内容尚未生成 AI 总结"}
        </p>
        {summary?.error_message && (
          <p className="mt-2 text-sm text-destructive">{summary.error_message}</p>
        )}
        {episode?.summary_status !== SummaryStatus.Processing && (
          <Button
            onClick={() => summarizeMutation.mutate(episodeId)}
            disabled={
              summarizeMutation.isPending ||
              episode?.transcript_status !== "completed"
            }
            className="mt-4"
          >
            {summarizeMutation.isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                启动中...
              </>
            ) : (
              "开始总结"
            )}
          </Button>
        )}
      </div>
    );
  }

  // No summary data
  if (!summary) {
    return (
      <div className="rounded-lg border border-dashed bg-muted/30 p-8 text-center">
        <p className="text-muted-foreground">暂无 AI 总结</p>
      </div>
    );
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString("zh-CN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Provider info */}
      <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
        {summary.model_used && <span>模型: {summary.model_used}</span>}
        {summary.provider && <span>提供商: {summary.provider}</span>}
        <span>生成于: {formatDate(summary.created_at)}</span>
      </div>

      {/* Summary content */}
      <div className="rounded-lg bg-muted/50 p-4">
        <p className="whitespace-pre-wrap text-sm leading-relaxed">
          {summary.content}
        </p>
      </div>

      {/* Key topics */}
      {summary.key_topics && summary.key_topics.length > 0 && (
        <div>
          <h4 className="mb-3 flex items-center gap-1.5 text-sm font-medium">
            <Lightbulb className="h-4 w-4 text-chart-4" />
            关键主题
          </h4>
          <div className="flex flex-wrap gap-2">
            {summary.key_topics.map((topic, i) => (
              <span
                key={i}
                className={cn(
                  "rounded-full px-2.5 py-0.5 text-xs font-medium",
                  TOPIC_COLORS[i % TOPIC_COLORS.length]
                )}
              >
                {topic}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Highlights */}
      {summary.highlights && summary.highlights.length > 0 && (
        <div>
          <h4 className="mb-3 text-sm font-medium">要点</h4>
          <ul className="space-y-2">
            {summary.highlights.map((highlight, i) => (
              <li key={i} className="flex items-start gap-3 text-sm">
                <span
                  className={cn(
                    "mt-1.5 h-1.5 w-1.5 flex-shrink-0 rounded-full",
                    HIGHLIGHT_COLORS[i % HIGHLIGHT_COLORS.length]
                  )}
                />
                <span className="flex-1">{highlight}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Star rating feedback */}
      <div className="flex items-center gap-2 border-t pt-4">
        <span className="text-xs text-muted-foreground">评价此总结</span>
        <StarRating
          rating={summary.rating}
          onRate={handleRate}
          disabled={feedbackMutation.isPending}
        />
      </div>
    </div>
  );
}
