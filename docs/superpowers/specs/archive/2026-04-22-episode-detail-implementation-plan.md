# Episode Detail Page Redesign — Implementation Plan

Date: 2026-04-22

## Overview

Redesign `/episodes/[id]` with: fixed-bottom audio player, tab-based content (概述/转录文本/AI 总结), media-platform style.

## Files to Create

| File | Purpose |
|------|---------|
| `frontend/src/components/episode-tabs.tsx` | Tab bar + content routing, URL-driven |
| `frontend/src/components/episode-info-card.tsx` | 2x2 grid metadata card for Overview tab |

## Files to Rewrite

| File | Change |
|------|--------|
| `frontend/src/app/episodes/[id]/page.tsx` | Full restructure: header → tabs → (fixed player separate) |
| `frontend/src/components/audio-player.tsx` | Full rewrite: fixed bottom card with all controls |

## Files to Modify

| File | Change |
|------|--------|
| `frontend/src/components/transcript-viewer.tsx` | Remove Card shell, add self-fetching, debounce search, mode toggle, "正在播放" label |
| `frontend/src/components/summary-card.tsx` | Remove Card shell, add self-fetching, reorder content, colored topic pills |
| `frontend/src/app/globals.css` | Add equalizer animations, progress tooltip, slide-up animation |

## Implementation Phases

### Phase 1: Audio Player (audio-player.tsx + globals.css)

**1.1 globals.css additions**

```
- @keyframes equalizer-1/2/3 (bounce animations for cover bars)
- .progress-tooltip (absolute positioned, bottom-aligned, with ::after arrow)
- .animate-slide-up (0.3s cubic-bezier slide from bottom)
- .player-shadow-top (box-shadow for player top edge)
```

**1.2 Rewrite audio-player.tsx**

New Props:
```typescript
interface AudioPlayerProps {
  audioUrl: string;
  title: string;
  podcastName?: string;
  coverUrl?: string;
}
```

Layout (4 rows, fixed bottom):
1. **Info row**: 48x48 cover thumbnail + title/podcast name + playing status (green dot + "播放中")
2. **Progress row**: time label | draggable range input with hover tooltip | time label
3. **Controls row**: ⏮15 ⏪ ▶(large orange circle) ⏩ ⏭15
4. **Tools row**: speed selector (0.5x-3x) | volume icon + slider

Key features:
- `position: fixed; bottom: 0; z-50` with `max-w-7xl` inner container
- Cover: image or gradient fallback + animated equalizer bars when playing
- Progress tooltip: `onMouseMove` on range container → calculate pct → format time
- States: playing (green indicator, animated bars), paused, loading (Loader2 spinner), no audio (hidden)
- Mobile: hide volume slider below `sm:` breakpoint, tighten padding

Internal components (not separate files):
- `CoverThumbnail` — cover image/gradient + equalizer overlay
- `ProgressTooltip` — hover timestamp preview

**1.3 Update page.tsx for player**

- AudioPlayer rendered at page level (NOT inside any tab — must stay mounted for TranscriptViewer seekTo)
- Content area: `pb-44` when `episode.audio_url` exists

### Phase 2: Page Layout + Tab System (page.tsx + episode-tabs.tsx + episode-info-card.tsx)

**2.1 Create episode-info-card.tsx**

```typescript
interface EpisodeInfoCardProps {
  publishedAt: string | null;
  duration: number | null;
  transcriptStatus: TranscriptStatus | null;
  summaryStatus: SummaryStatus | null;
}
```

- Card container with `grid grid-cols-2 gap-4`
- Each cell: icon + label (small muted) + value
- Reuse `StatusBadge`, `formatDate`, `formatDuration`

**2.2 Create episode-tabs.tsx**

```typescript
interface EpisodeTabsProps {
  episodeId: string;
  episode: Episode;
}
```

Tab system:
- Custom implementation (NOT Radix Tabs) — URL-driven via `useSearchParams`
- `?tab=overview|transcript|summary`, default `overview`
- `router.push(pathname + '?tab=' + tab, { scroll: false })` on switch
- Tab bar: `flex gap-6 border-b`, active tab has `border-b-2 border-primary text-primary`

Tab content (conditional rendering):
- **overview**: EpisodeInfoCard → action buttons (transcribe/summarize mutations) → divider → ExpandableDescription
- **transcript**: lazy `useTranscript` → TranscriptViewer
- **summary**: lazy `useSummary` → SummaryCard

Mutation handlers (`useTranscribeEpisode`, `useSummarizeEpisode`) live inside episode-tabs.tsx.

Tab trigger status indicators:
- `completed`: small green dot
- `processing`: Loader2 spinner
- Other: no indicator

**2.3 Restructure page.tsx**

```
page.tsx
├── Suspense wrapper (useSearchParams requirement)
│   └── EpisodeDetailContent
│       ├── useEpisode(id)
│       ├── Loading/error states
│       ├── Back navigation → /podcasts/{podcast_id}
│       ├── Title (h1, font-display)
│       ├── Meta row: date + duration + status badges
│       ├── <EpisodeTabs /> (handles all tab content)
│       └── {episode.audio_url && <AudioPlayer ... />} (always mounted)
```

Remove from page.tsx:
- `useTranscript` / `useSummary` top-level calls
- Direct TranscriptViewer / SummaryCard rendering
- Inline AudioPlayer, action buttons, description area

### Phase 3: Tab Content Components (transcript-viewer.tsx + summary-card.tsx)

**3.1 Rewrite transcript-viewer.tsx**

New Props:
```typescript
interface TranscriptViewerProps {
  episodeId: string;
  isActive: boolean;
}
```

Changes:
- Self-fetching: `useTranscript(episodeId, { enabled: isActive && episode?.transcript_status === 'completed' })`
- Remove `<Card>` shell and CardHeader
- Add metadata bar at top: language + word count + model (horizontal, small muted text)
- Add debounce to search: `debouncedSearch` state via `useEffect` + `setTimeout(300ms)`
- Add mode toggle: 分段/纯文本 buttons (use `Button variant="secondary"/"ghost"`)
- Playing segment: `border-l-2 border-l-primary bg-primary/10` + "正在播放" label
- Handle states: loading (Loader2), no transcript (show trigger button), error

**3.2 Rewrite summary-card.tsx**

New Props:
```typescript
interface SummaryCardProps {
  episodeId: string;
  isActive: boolean;
}
```

Changes:
- Self-fetching: `useSummary(episodeId, { enabled: isActive && episode?.summary_status === 'completed' })`
- Remove `<Card>` shell and CardHeader
- Reorder: provider info → summary content → key topics → highlights
- Key topics: colored pills using chart colors (`bg-chart-N/15 text-chart-N`)
- Highlights: colored dots cycling chart colors
- Handle states: loading, no summary (show trigger button), error

## Execution Order

```
Phase 1: globals.css → audio-player.tsx → page.tsx (player integration)
    ↓
Phase 2: episode-info-card.tsx → episode-tabs.tsx → page.tsx (full restructure)
    ↓
Phase 3: transcript-viewer.tsx → summary-card.tsx
    ↓
Verify: dev server, all tabs, player controls, responsive, dark/light mode
```

## Key Constraints

- `useAudioPlayer` hook and `useAudioStore` — NO changes
- Backend API — NO changes
- AudioPlayer must render at page level (outside tabs) to keep seekTo working
- Tab state in URL params for shareability and browser back/forward
- Content area `pb-44` to avoid being hidden behind fixed player (~170px)
