import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_durations.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/platform/platform_helper.dart';
import 'package:sonde/features/podcast/presentation/providers/podcast_search_provider.dart';

/// Search input widget for the discover page.
///
/// Uses a filled surface container background with a prominent border
/// and focus glow effect for better visual prominence.
class DiscoverSearchInput extends StatefulWidget {
  const DiscoverSearchInput({
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    super.key,
    this.searchMode = PodcastSearchMode.podcasts,
    this.isDense = false,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final PodcastSearchMode searchMode;
  final bool isDense;

  @override
  State<DiscoverSearchInput> createState() => _DiscoverSearchInputState();
}

class _DiscoverSearchInputState extends State<DiscoverSearchInput> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.searchFocusNode.addListener(_onFocusChange);
    _isFocused = widget.searchFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant DiscoverSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchFocusNode != widget.searchFocusNode) {
      oldWidget.searchFocusNode.removeListener(_onFocusChange);
      widget.searchFocusNode.addListener(_onFocusChange);
      _isFocused = widget.searchFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    widget.searchFocusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.searchFocusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hintLabel =
        widget.searchMode == PodcastSearchMode.episodes
            ? l10n.podcast_search_section_episodes
            : l10n.podcast_search_section_podcasts;
    final isZh =
        Localizations.localeOf(context).languageCode.startsWith('zh');
    final hintText = isZh
        ? '${l10n.search}$hintLabel...'
        : '${l10n.search} $hintLabel...';

    final borderColor = _isFocused
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.5);
    final borderWidth = _isFocused ? 1.6 : 1.0;
    final backgroundColor = _isFocused
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHighest;

    return RepaintBoundary(
      key: const Key('podcast_discover_search_input_boundary'),
      child: AnimatedContainer(
        key: const Key('podcast_discover_search_bar'),
        duration: AppDurations.entranceNormal,
        curve: Curves.easeOutCubic,
        height: widget.isDense ? 44 : 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          // Pill radius echoes the hero CTA and page-dots language.
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ]
              : [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: widget.isDense ? context.spacing.smMd : context.spacing.md,
              ),
              child: Icon(
                Icons.search,
                size: widget.isDense ? 18 : 20,
                color: _isFocused
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(
              width: widget.isDense ? context.spacing.smMd : context.spacing.sm,
            ),
            Expanded(
              // Inline platform branching: custom search decoration (dense mode, no border)
              // doesn't map cleanly to AdaptiveTextField/AdaptiveSearchBar APIs.
              child: PlatformHelper.isApple(context)
                  ? CupertinoTextField(
                      key: const Key('podcast_discover_search_input'),
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyMedium,
                      placeholder: hintText,
                      placeholderStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      decoration: const BoxDecoration(),
                      padding: EdgeInsets.zero,
                      onChanged: widget.onSearchChanged,
                    )
                  : TextField(
                      key: const Key('podcast_discover_search_input'),
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: hintText,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.searchController,
              builder: (context, value, _) {
                if (value.text.isNotEmpty) {
                  return IconButton(
                    onPressed: widget.onClearSearch,
                    tooltip: l10n.clear,
                    icon: Icon(
                      Icons.clear,
                      size: widget.isDense ? 16 : 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            SizedBox(
              width: widget.isDense ? context.spacing.smMd : context.spacing.md,
            ),
          ],
        ),
      ),
    );
  }
}
