part of 'podcast_bottom_player_widget.dart';

class _TransportRow extends StatelessWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const RepaintBoundary(
          child: _SkipButton(
            keyValue: 'podcast_bottom_player_rewind_10',
            deltaMs: -10000,
            icon: Icons.replay_10_rounded,
            tooltipLocalizationKey: _TooltipKey.rewind10,
            iconSize: 36,
          ),
        ),
        SizedBox(width: context.spacing.mdLg),
        const RepaintBoundary(
          child: _PlayPauseButtonLarge(),
        ),
        SizedBox(width: context.spacing.mdLg),
        const RepaintBoundary(
          child: _SkipButton(
            keyValue: 'podcast_bottom_player_forward_30',
            deltaMs: 30000,
            icon: Icons.forward_30_rounded,
            tooltipLocalizationKey: _TooltipKey.forward30,
            iconSize: 36,
          ),
        ),
      ],
    );
  }
}

/// Secondary actions below the transport row: playback speed + queue.
class _ExpandedSecondaryActions extends StatelessWidget {
  const _ExpandedSecondaryActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Speed chip: isolated Consumer — only rebuilds when rate changes.
          Consumer(
            builder: (context, ref, _) {
              return RepaintBoundary(
                child: _PlaybackSpeedChip(
                  speed: ref.watch(audioPlaybackRateProvider),
                  onTap: () => _showSpeedSelector(context, ref),
                ),
              );
            },
          ),
          // Queue button: isolated Consumer so it does not rebuild while
          // queue-sheet state changes.
          Consumer(
            builder: (context, ref, _) {
              final queueSheetOpen =
                  ref.watch(podcastPlayerQueueSheetOpenProvider);
              return IconButton(
                key: const Key('podcast_bottom_player_playlist'),
                tooltip: l10n.podcast_player_list,
                iconSize: 26,
                onPressed: queueSheetOpen
                    ? null
                    : () => _showQueueSheet(context, ref),
                icon: const Icon(Icons.playlist_play_rounded),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PlaybackSpeedChip extends StatelessWidget {
  const _PlaybackSpeedChip({required this.speed, required this.onTap});

  final double speed;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.pillRadius,
      child: AdaptiveInkWell(
        key: const Key('podcast_bottom_player_speed'),
        borderRadius: AppRadius.pillRadius,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.mdLg,
            vertical: context.spacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillRadius,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            formatPlaybackSpeed(speed),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SleepTimerButton extends ConsumerWidget {
  const _SleepTimerButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isActive = ref.watch(audioSleepTimerActiveProvider);
    final theme = Theme.of(context);

    return IconButton(
      key: const Key('podcast_bottom_player_sleep'),
      tooltip: l10n.podcast_player_sleep_mode,
      onPressed: onPressed,
      icon: Transform.flip(
        flipX: true,
        child: Icon(
          isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum _TooltipKey { rewind10, forward30 }

class _SkipButton extends ConsumerWidget {
  const _SkipButton({
    required this.keyValue,
    required this.deltaMs,
    required this.icon,
    required this.tooltipLocalizationKey,
    this.iconSize = 30,
  });

  final String keyValue;
  final int deltaMs;
  final IconData icon;
  final _TooltipKey tooltipLocalizationKey;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tooltip = switch (tooltipLocalizationKey) {
      _TooltipKey.rewind10 => l10n.podcast_player_rewind_10,
      _TooltipKey.forward30 => l10n.podcast_player_forward_30,
    };

    return IconButton(
      key: Key(keyValue),
      tooltip: tooltip,
      iconSize: iconSize,
      onPressed: () {
        AdaptiveHaptic.lightImpact();
        // Use ref.read to avoid rebuilding on every progress tick (500ms).
        // Position is only needed at tap time, not reactively.
        final progress = ref.read(audioMiniProgressProvider);
        final next = (progress.positionMs + deltaMs).clamp(
          0,
          progress.durationMs,
        );
        ref.read(audioPlayerProvider.notifier).seekTo(next);
      },
      icon: Icon(icon),
    );
  }
}

class _PlayPauseButtonLarge extends ConsumerWidget {
  const _PlayPauseButtonLarge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(audioPlayPauseStateProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        key: const Key('podcast_bottom_player_play_pause'),
        iconSize: 46,
        tooltip: transport.isPlaying
            ? l10n.podcast_player_pause
            : l10n.podcast_player_play,
        onPressed: () async {
          AdaptiveHaptic.mediumImpact();
          if (transport.isLoading) {
            return;
          }
          if (transport.isPlaying) {
            await ref.read(audioPlayerProvider.notifier).pause();
          } else {
            await ref.read(audioPlayerProvider.notifier).resume();
          }
        },
        icon: transport.isLoading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator.adaptive(strokeWidth: 3),
              )
            : Icon(
                transport.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
              ),
      ),
    );
  }
}

class _MiniPlayPauseButton extends ConsumerWidget {
  const _MiniPlayPauseButton({
    required super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(audioPlayPauseStateProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: IconButton(
        key: key,
        tooltip: transport.isPlaying
            ? l10n.podcast_player_pause
            : l10n.podcast_player_play,
        onPressed: () async {
          AdaptiveHaptic.mediumImpact();
          if (transport.isLoading) {
            return;
          }
          if (transport.isPlaying) {
            await ref.read(audioPlayerProvider.notifier).pause();
          } else {
            await ref.read(audioPlayerProvider.notifier).resume();
          }
        },
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          maximumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        icon: transport.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onSurface),
                ),
              )
            : Icon(
                transport.isPlaying
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                size: 28,
                color: theme.colorScheme.onSurface,
              ),
      ),
    );
  }
}

class _MiniProgressIndicator extends ConsumerWidget {
  const _MiniProgressIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioMiniProgressProvider);
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: LinearProgressIndicator(
        key: const Key('podcast_bottom_player_mini_progress'),
        value: progress.progress,
        minHeight: 4,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
      ),
    );
  }
}

class _MiniProgressText extends ConsumerWidget {
  const _MiniProgressText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioMiniProgressProvider);
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: Text(
        key: const Key('podcast_bottom_player_mini_time'),
        '${progress.formattedPosition} / ${progress.formattedDuration}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: theme.textTheme.labelSmall?.fontSize ?? 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lgRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: PodcastImageWidget(
          imageUrl: imageUrl,
          width: size,
          height: size,
          iconSize: size * 0.5,
        ),
      ),
    );
  }
}
