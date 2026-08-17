import 'package:material_ui/material_ui.dart';

import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/theme/app_colors.dart';

class PasswordRequirementItem extends StatelessWidget {

  const PasswordRequirementItem({
    required this.text, required this.isValid, super.key,
  });
  final String text;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    const validColor = AppColors.accentWarm;
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid
                ? validColor
                : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isValid
                    ? validColor
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
