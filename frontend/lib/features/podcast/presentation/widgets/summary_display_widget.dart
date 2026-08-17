import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_durations.dart';

/// Widget for displaying AI-generated podcast episode summaries.
///
/// Features:
/// - Markdown rendering with custom styling
/// - Text selection support
/// - Scroll-to-top capability
/// - State persistence with AutomaticKeepAliveClientMixin
class SummaryDisplayWidget extends ConsumerStatefulWidget {

  const SummaryDisplayWidget({
    required this.summary, super.key,
    this.compact = false,
    this.useInternalScrolling = true,
  });

  /// The summary content in markdown format
  final String summary;

  /// Whether to use compact layout (reduced spacing)
  final bool compact;

  /// Whether to handle scrolling internally.
  /// When false, the widget content will not be wrapped in SingleChildScrollView.
  final bool useInternalScrolling;

  @override
  ConsumerState<SummaryDisplayWidget> createState() =>
      SummaryDisplayWidgetState();
}

class SummaryDisplayWidgetState
    extends ConsumerState<SummaryDisplayWidget>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  /// Scrolls the content view to the top with animation.
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: AppDurations.scrollAnimation,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Markdown content with selection support
        SelectionArea(
          child: RepaintBoundary(
            child: MarkdownBody(
              data: widget.summary,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyLarge?.copyWith(
                  height: widget.compact ? 1.55 : 1.65,
                ),
                h1: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                h2: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                h3: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                listBullet: theme.textTheme.bodyLarge,
                strong: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.useInternalScrolling) {
      return SingleChildScrollView(
        controller: _scrollController,
        child: content,
      );
    }

    return content;
  }
}
