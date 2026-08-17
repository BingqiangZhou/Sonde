# Episode Detail Page Redesign

Date: 2026-04-22

## Summary

Redesign the episode detail page (`/episodes/[id]`) with a media-platform style layout. The page features a tab-based content area (Overview / Transcript / AI Summary) with a full-featured audio player card fixed at the bottom of the viewport.

## Goals

- Fix messy layout — establish clear visual hierarchy
- Improve player experience — full controls always accessible
- Unify design language — align with media-platform patterns (YouTube/Spotify)

## Page Structure (top to bottom)

```
┌──────────────────────────────────┐
│ ← 返回 播客名称                   │  Back navigation
├──────────────────────────────────┤
│ EP128: 深入探讨人工智能的未来       │  Title (h1, bold)
│ 📅 2024-03-15  ⏱ 45:30          │  Meta row: date + duration
│ ✓ 已转录  ✓ 已总结                │  Status badges
├──────────────────────────────────┤
│ [概述] [转录文本] [AI 总结]        │  Tab bar
├──────────────────────────────────┤
│                                  │
│  Tab content (scrollable)        │  Content area
│  ...                             │  padding-bottom: player height
│                                  │
├──────────────────────────────────┤
│ 🎙 EP128... | ━━━●━━━ | ▶ 1.0x  │  Fixed bottom player card
│ ⏮15 ⏪ ▶ ⏩ ⏭15    🔊 ━━━━     │  Full controls always visible
└──────────────────────────────────┘
```

## Component Breakdown

### 1. Back Navigation

- Link back to parent podcast page (`/podcasts/{podcast_id}`)
- Shows podcast name as link text
- Left arrow icon prefix

### 2. Episode Header

- **Title**: Episode title, large bold text with fade-in animation
- **Meta row**: Published date (Calendar icon) + Duration (Clock icon) on one line
- **Status badges**: Transcript status + Summary status using `StatusBadge` component

### 3. Tab Bar

- Three tabs: 概述 (Overview), 转录文本 (Transcript), AI 总结 (AI Summary)
- Active tab: orange underline + orange text
- Inactive tab: muted text
- URL sync: update search params on tab switch for shareable URLs

### 4. Tab Content

#### Overview Tab

Order (top to bottom):

1. **Episode info card** — 2x2 grid in a card:
   - 发布日期 (published date)
   - 时长 (duration)
   - 转录状态 (transcript status with color)
   - AI 总结状态 (summary status with color)
2. **Action buttons** — "开始转录" (primary) and "开始总结" (outline) buttons
   - Buttons hidden or change label when processing/completed
3. **Divider** — subtle border-top separator
4. **Description** — expandable episode description via `ExpandableDescription` component
   - HTML shownotes rendered with prose styling
   - Collapsed: 4 lines with gradient fade overlay
   - "展开全文" / "收起内容" toggle

#### Transcript Tab

Order (top to bottom):

1. **Metadata bar** — language, word count, model used (horizontal, small text)
2. **Search bar + mode toggle** — search input (debounced) + segmented/plain text mode selector
3. **Transcript segments** — list of timestamped segments:
   - Each segment: clickable timestamp button + text
   - Currently playing segment: orange left border + highlighted background + "正在播放" label
   - Clicking a timestamp seeks the audio player to that position
   - Search matches highlighted with `<mark>` elements
   - Auto-scroll to currently playing segment (with user-scroll override)

#### AI Summary Tab

Order (top to bottom):

1. **Provider info** — model name + generation date (small muted text)
2. **Summary content** — main summary text in a card with muted background
3. **Key topics** — colored pill badges (each topic gets a distinct color)
4. **Highlights** — bulleted list with colored dots, each highlight is a key takeaway

### 5. Audio Player (Fixed Bottom)

The full player card is **position: fixed** at the bottom of the viewport. It is NOT inline in the page flow.

#### Layout

```
┌──────────────────────────────────────┐
│ 🎙 EP128: 深入探讨人工智能的未来  🟢播放中 │  Cover + title + status
│ ━━━━━━━━━━━●━━━━━━━━━━━━━━━━━━━      │  Progress bar (draggable)
│ 15:48                          45:30  │  Time display
│    ⏮15  ⏪    ▶    ⏩    ⏭15         │  Main transport controls
│ 1.0x                    🔊 ━━━━━━    │  Speed + volume
└──────────────────────────────────────┘
```

#### Features

- **Cover thumbnail**: 48x48px rounded square with podcast art / fallback gradient icon
- **Title + podcast name**: truncated with ellipsis on overflow
- **Playing indicator**: animated equalizer bars on cover + green pulse dot + "播放中" text
- **Progress bar**: draggable slider with thumb, hover shows timestamp preview, gradient fill for played portion
- **Transport controls**: skip back/forward 15s, rewind/forward, play/pause (large circular orange button with shadow)
- **Speed selector**: dropdown (0.5x to 3x)
- **Volume control**: icon + horizontal slider

#### States

- **Playing**: green indicator, animated bars on cover, progress updates in real-time
- **Paused**: paused indicator, static cover icon
- **Loading**: spinning loader replaces play button
- **No audio**: player card hidden entirely (episode has no `audio_url`)

#### Content Area Padding

The scrollable content area must have `padding-bottom` equal to the fixed player height (~160-180px on desktop) to prevent content being hidden behind the player.

#### Responsive Behavior

- **Desktop (>=1024px)**: Full player card as described above
- **Mobile (<1024px)**: Same layout, controls may stack or reduce gaps. Player card takes full width.

## Components to Modify

| Component | Change |
|-----------|--------|
| `episodes/[id]/page.tsx` | Full rewrite — new layout structure, tabs, fixed player |
| `audio-player.tsx` | Rewrite — new visual design, remove inline variant, fixed position only |
| `transcript-viewer.tsx` | Update — new tab context, remove standalone header, adjust styling |
| `summary-card.tsx` | Update — new tab context, adjust styling for tab layout |
| `expandable-description.tsx` | Minor — styling adjustments for new context |
| `status-badge.tsx` | Keep as-is |

## Components to Create

| Component | Purpose |
|-----------|---------|
| `episode-tabs.tsx` | Tab bar + tab content routing (概述/转录文本/AI 总结) |
| `episode-info-card.tsx` | 2x2 grid card showing episode metadata |

## Data Flow

- Page fetches episode via `useEpisode(id)`
- Transcript fetched only when Transcript tab is active (lazy)
- Summary fetched only when Summary tab is active (lazy)
- Tab state stored in URL search params (`?tab=overview|transcript|summary`)
- Audio player reads from `useAudioStore` (Zustand) — no changes to store needed

## What Stays the Same

- Backend API — no changes
- TanStack Query hooks — no changes
- `useAudioPlayer` hook — no changes (manages HTML5 Audio element)
- `useAudioStore` (Zustand) — no changes
- Types — no changes
- Sidebar layout — no changes
