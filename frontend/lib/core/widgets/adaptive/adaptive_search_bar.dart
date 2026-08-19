import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/platform/platform_helper.dart';

/// Adaptive search bar.
///
/// iOS: [CupertinoSearchTextField] with rounded gray background.
/// Android: Material [TextField] with search decoration and pill shape,
/// since [SearchBar] does not expose `onSubmitted`.
class AdaptiveSearchBar extends StatefulWidget {
  const AdaptiveSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.placeholder,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? placeholder;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AdaptiveSearchBar> createState() => _AdaptiveSearchBarState();
}

class _AdaptiveSearchBarState extends State<AdaptiveSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    // Only dispose controllers we created.
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      return CupertinoSearchTextField(
        controller: _controller,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        placeholder: widget.placeholder,
        autofocus: widget.autofocus,
        focusNode: _focusNode,
        style: CupertinoTheme.of(context).textTheme.textStyle,
      );
    }

    // Material: use TextField with SearchBar-like styling so we can
    // support onSubmitted (which SearchBar does not expose).
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        contentPadding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        border: OutlineInputBorder(
          borderRadius: AppRadius.pillRadius,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
