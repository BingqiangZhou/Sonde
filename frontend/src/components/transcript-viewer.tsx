"use client";

import { useState, useMemo, useCallback, useRef, useEffect } from "react";
import { Search, Loader2, Globe, BarChart3, Cpu, Star } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useAudioStore } from "@/stores/audio-store";
import { useTranscript, useEpisode, useTranscribeEpisode } from "@/lib/queries";
import { useSubmitTranscriptFeedback } from "@/lib/api";
import { TranscriptStatus, type TranscriptSegment } from "@/types";
import { cn } from "@/lib/utils";

interface TranscriptViewerProps {
  episodeId: string;
  isActive: boolean;
}

function formatTimestamp(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) {
    return `${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  }
  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
}

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
                "h-3 w-3 transition-colors",
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

export function TranscriptViewer({ episodeId, isActive }: TranscriptViewerProps) {
  const [searchTerm, setSearchTerm] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [displayMode, setDisplayMode] = useState<"segments" | "plain">("segments");

  // Get episode for status
  const { data: episode } = useEpisode(episodeId);

  // Fetch transcript only when active and completed
  const { data: transcript, isLoading, error } = useTranscript(episodeId, {
    enabled:
      isActive &&
      (episode?.transcript_status === TranscriptStatus.Completed ||
        episode?.transcript_status === TranscriptStatus.Failed),
  });

  const transcribeMutation = useTranscribeEpisode();
  const feedbackMutation = useSubmitTranscriptFeedback();

  const handleRate = (rating: number) => {
    if (!transcript) return;
    feedbackMutation.mutate({ id: transcript.id, data: { rating } });
  };

  const hasSegments = transcript?.segments && transcript.segments.length > 0;

  // Lock to plain mode if no segments exist
  useEffect(() => {
    if (!hasSegments && transcript) {
      setDisplayMode("plain");
    }
  }, [hasSegments, transcript]);

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(searchTerm);
    }, 300);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  const currentTime = useAudioStore((s) => s.currentTime);
  const seekTo = useAudioStore((s) => s.seekTo);

  const scrollContainerRef = useRef<HTMLDivElement>(null);
  const lastUserScrollRef = useRef<number>(0);
  const segmentRefs = useRef<Map<number, HTMLDivElement>>(new Map());

  const filteredSegments = useMemo(() => {
    if (!hasSegments) return null;
    if (!debouncedSearch.trim()) return transcript.segments!;

    const lowerSearch = debouncedSearch.toLowerCase();
    return transcript.segments!.filter((seg) =>
      seg.text.toLowerCase().includes(lowerSearch)
    );
  }, [transcript, debouncedSearch, hasSegments]);

  const highlightedContent = useMemo(() => {
    if (hasSegments) return null;
    if (!debouncedSearch.trim()) return transcript?.content;

    const escaped = debouncedSearch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regex = new RegExp(`(${escaped})`, "gi");
    const parts = transcript!.content.split(regex);

    return parts.map((part, i) =>
      regex.test(part) ? (
        <mark
          key={i}
          className="rounded bg-yellow-200 px-0.5 dark:bg-yellow-800"
        >
          {part}
        </mark>
      ) : (
        part
      )
    );
  }, [transcript, debouncedSearch, hasSegments]);

  const highlightText = useCallback(
    (text: string) => {
      if (!debouncedSearch.trim()) return text;
      const escaped = debouncedSearch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const regex = new RegExp(`(${escaped})`, "gi");
      const parts = text.split(regex);
      return parts.map((part, i) =>
        regex.test(part) ? (
          <mark
            key={i}
            className="rounded bg-yellow-200 px-0.5 dark:bg-yellow-800"
          >
            {part}
          </mark>
        ) : (
          part
        )
      );
    },
    [debouncedSearch]
  );

  const isSegmentActive = useCallback(
    (seg: TranscriptSegment) => {
      return currentTime >= seg.start && currentTime < seg.end;
    },
    [currentTime]
  );

  // Auto-scroll to active segment
  useEffect(() => {
    if (!hasSegments || debouncedSearch.trim()) return;
    if (Date.now() - lastUserScrollRef.current < 5000) return;

    const activeIdx = transcript!.segments!.findIndex(
      (seg) => currentTime >= seg.start && currentTime < seg.end
    );
    if (activeIdx < 0) return;

    const el = segmentRefs.current.get(activeIdx);
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }, [currentTime, hasSegments, debouncedSearch, transcript]);

  const handleScroll = useCallback(() => {
    lastUserScrollRef.current = Date.now();
  }, []);

  // Loading state
  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
        <span className="ml-2 text-muted-foreground">加载转录文本...</span>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-6 text-center">
        <p className="text-destructive">加载转录文本失败</p>
        <p className="mt-1 text-sm text-muted-foreground">{(error as Error).message}</p>
      </div>
    );
  }

  // Not completed state
  if (episode?.transcript_status !== TranscriptStatus.Completed) {
    return (
      <div className="rounded-lg border border-dashed bg-muted/30 p-8 text-center">
        <p className="text-muted-foreground">
          {episode?.transcript_status === TranscriptStatus.Processing
            ? "转录处理中..."
            : episode?.transcript_status === TranscriptStatus.Failed
            ? "转录失败"
            : "此内容尚未转录"}
        </p>
        {transcript?.error_message && (
          <p className="mt-2 text-sm text-destructive">{transcript.error_message}</p>
        )}
        {episode?.transcript_status !== TranscriptStatus.Processing && (
          <Button
            onClick={() => transcribeMutation.mutate(episodeId)}
            disabled={transcribeMutation.isPending}
            className="mt-4"
          >
            {transcribeMutation.isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                启动中...
              </>
            ) : (
              "开始转录"
            )}
          </Button>
        )}
      </div>
    );
  }

  // No transcript data
  if (!transcript) {
    return (
      <div className="rounded-lg border border-dashed bg-muted/30 p-8 text-center">
        <p className="text-muted-foreground">暂无转录文本</p>
      </div>
    );
  }

  return (
    <div className="space-y-4 animate-fade-in">
      {/* Metadata bar */}
      <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
        {transcript.language && (
          <span className="flex items-center gap-1">
            <Globe className="h-3 w-3" />
            {transcript.language}
          </span>
        )}
        {transcript.word_count && (
          <span className="flex items-center gap-1">
            <BarChart3 className="h-3 w-3" />
            {transcript.word_count.toLocaleString()} 词
          </span>
        )}
        {transcript.model_used && (
          <span className="flex items-center gap-1">
            <Cpu className="h-3 w-3" />
            {transcript.model_used}
          </span>
        )}
        <span className="mx-0.5 text-muted-foreground/30">|</span>
        <span className="flex items-center gap-1">
          评价此转录
          <StarRating
            rating={transcript.rating}
            onRate={handleRate}
            disabled={feedbackMutation.isPending}
          />
        </span>
      </div>

      {/* Search bar and mode toggle */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            type="text"
            placeholder="搜索转录内容..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>
        {hasSegments && (
          <div className="flex gap-1">
            <Button
              variant={displayMode === "segments" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setDisplayMode("segments")}
            >
              分段
            </Button>
            <Button
              variant={displayMode === "plain" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setDisplayMode("plain")}
            >
              纯文本
            </Button>
          </div>
        )}
      </div>

      {/* Transcript content */}
      <div
        ref={scrollContainerRef}
        onScroll={handleScroll}
        className="max-h-[500px] overflow-y-auto rounded-lg bg-muted/50 p-4"
      >
        {hasSegments && displayMode === "segments" ? (
          <div className="space-y-2 text-sm leading-relaxed">
            {filteredSegments?.map((seg, i) => {
              const active = isSegmentActive(seg);
              return (
                <div
                  key={i}
                  ref={(el) => {
                    if (el) segmentRefs.current.set(i, el);
                  }}
                  className={cn(
                    "flex gap-3 rounded px-2 py-1 transition-colors",
                    active && "border-l-2 border-l-primary bg-primary/10"
                  )}
                >
                  <div className="flex shrink-0 items-start gap-2">
                    <button
                      className="cursor-pointer font-mono text-xs text-primary/70 transition-colors hover:text-primary hover:underline"
                      onClick={() => seekTo(seg.start)}
                      aria-label={`跳转到 ${formatTimestamp(seg.start)}`}
                    >
                      [{formatTimestamp(seg.start)}]
                    </button>
                    {active && (
                      <span className="rounded bg-primary/20 px-1.5 py-0.5 text-[10px] text-primary">
                        正在播放
                      </span>
                    )}
                  </div>
                  <span className="whitespace-pre-wrap">
                    {highlightText(seg.text)}
                  </span>
                </div>
              );
            })}
          </div>
        ) : (
          <pre className="whitespace-pre-wrap text-sm leading-relaxed">
            {highlightedContent}
          </pre>
        )}
      </div>
    </div>
  );
}
