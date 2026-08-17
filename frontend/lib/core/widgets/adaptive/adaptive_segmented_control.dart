import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive segmented control.
///
/// iOS: [CupertinoSlidingSegmentedControl] with sliding highlight.
/// Android: Material [SegmentedButton].
class AdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
  const AdaptiveSegmentedControl({
    required this.segments,
    required this.selected,
    super.key,
    this.onChanged,
  });

  final Map<T, Widget> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        onValueChanged: (val) {
          if (val != null) onChanged?.call(val);
        },
        children: segments,
      );
    }

    return SegmentedButton<T>(
      segments: segments.entries
          .map((e) => ButtonSegment(value: e.key, label: e.value))
          .toList(),
      selected: {selected},
      onSelectionChanged: (set) {
        if (set.isNotEmpty && set.first != selected) {
          onChanged?.call(set.first);
        }
      },
    );
  }
}
