import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_spacing.dart';

import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/router/app_router.dart';
import 'package:sonde/core/widgets/adaptive_sheet_helper.dart';
import 'package:sonde/features/podcast/presentation/widgets/selector_sheet_common.dart';

/// Represents the user's sleep timer selection.
class SleepTimerSelection {

  const SleepTimerSelection({
    this.duration,
    this.afterEpisode = false,
    this.cancel = false,
  });

  const SleepTimerSelection.afterEpisode()
    : duration = null,
      afterEpisode = true,
      cancel = false;

  const SleepTimerSelection.cancel()
    : duration = null,
      afterEpisode = false,
      cancel = true;
  /// Duration-based timer (null if after-episode mode).
  final Duration? duration;

  /// If true, stop after the current episode ends.
  final bool afterEpisode;

  /// If true, cancel the current timer.
  final bool cancel;
}

/// Preset durations for the sleep timer.
const _kSleepTimerPresets = [
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(minutes: 60),
  Duration(minutes: 90),
];

String _formatPresetDuration(Duration d, BuildContext context) {
  final l10n = context.l10n;
  if (d.inMinutes >= 60) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    return mins > 0
        ? l10n.player_hours_minutes(hours, mins)
        : l10n.player_hours(hours);
  }
  return l10n.player_minutes(d.inMinutes);
}

/// Shows a bottom sheet for selecting a sleep timer option.
Future<SleepTimerSelection?> showSleepTimerSelectorSheet({
  required BuildContext context,
  required bool isTimerActive,
}) {
  final fallbackContext = appNavigatorKey.currentContext;
  final resolvedContext = Navigator.maybeOf(context) != null
      ? context
      : fallbackContext;
  if (resolvedContext == null) {
    return Future<SleepTimerSelection?>.value();
  }

  return showAdaptiveSheet<SleepTimerSelection>(
    context: resolvedContext,
    builder: (context) {
      final l10n = context.l10n;
      final theme = Theme.of(context);

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorSheetHeader(
                icon: Icons.bedtime_rounded,
                title: l10n.player_sleep_timer_title,
                subtitle: l10n.player_sleep_timer_desc,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.spacing.md,
                  context.spacing.md,
                  context.spacing.md,
                  context.spacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Duration presets
                    Wrap(
                      spacing: context.spacing.sm,
                      runSpacing: context.spacing.sm,
                      children: [
                        for (final preset in _kSleepTimerPresets)
                          SelectorOptionPill(
                            key: Key('sleep_timer_option_${preset.inMinutes}'),
                            label: _formatPresetDuration(preset, context),
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pop(SleepTimerSelection(duration: preset));
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: context.spacing.mdLg),
                    // After current episode
                    SelectorActionRow(
                      icon: Icons.stop_circle_rounded,
                      label: l10n.player_stop_after_episode,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).pop(const SleepTimerSelection.afterEpisode());
                      },
                    ),
                    // Cancel timer (only when active)
                    if (isTimerActive) ...[
                      SizedBox(height: context.spacing.sm),
                      SelectorActionRow(
                        icon: Icons.timer_off_rounded,
                        label: l10n.player_cancel_timer,
                        foregroundColor: theme.colorScheme.error,
                        onTap: () {
                          Navigator.of(
                            context,
                          ).pop(const SleepTimerSelection.cancel());
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
