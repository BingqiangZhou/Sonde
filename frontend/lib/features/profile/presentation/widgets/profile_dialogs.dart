import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/localization/locale_provider.dart';
import 'package:sonde/core/network/exceptions/network_exceptions.dart';
import 'package:sonde/core/platform/platform_helper.dart';
import 'package:sonde/core/theme/theme_provider.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_dialog.dart';
import 'package:sonde/core/widgets/app_dialog_helper.dart';
import 'package:sonde/core/widgets/top_floating_notice.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/shared/widgets/custom_text_field.dart';

// Profile page dialogs, extracted from profile_page.dart. All dialogs share
// the AppDialog shell via showAppDialog; profile forms use a wider maxWidth.

void showSecurityDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
      return AppDialog(
        maxWidth: 720,
        title: Text(l10n.profile_security),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdaptiveListTile(
              leading: Icon(Icons.phone_android, color: iconColor),
              title: Text(l10n.profile_two_factor_auth),
              subtitle: Text(
                l10n.profile_two_factor_coming_soon,
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.schedule, size: 20),
            ),
          ],
        ),
        actions: [
          AdaptiveButton(
            style: AdaptiveButtonStyle.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      );
    },
  );
}

void showLanguageDialog(BuildContext context) {
  showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (dialogContext, ref, _) {
          final currentCode = ref.watch(localeCodeProvider);
          final l10n = dialogContext.l10n;
          final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

          return AppDialog(
            maxWidth: 720,
            title: Text(l10n.language),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveSegmentedControl<String>(
                  key: const Key('profile_language_segmented_button'),
                  segments: {
                    kLanguageSystem: Text(l10n.languageFollowSystem),
                    kLanguageEnglish: Text(l10n.languageEnglish),
                    kLanguageChinese: Text(l10n.languageChinese),
                  },
                  selected: currentCode,
                  onChanged: (value) async {
                    await ref
                        .read(localeProvider.notifier)
                        .setLanguageCode(value);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
                SizedBox(height: dialogContext.spacing.md),
                Text(
                  l10n.languageFollowSystem,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodySmall?.copyWith(color: iconColor),
                ),
              ],
            ),
            actions: [
              AdaptiveButton(
                style: AdaptiveButtonStyle.text,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showProfileAboutDialog(BuildContext context) async {
  final l10n = context.l10n;
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
      return AppDialog(
        maxWidth: 720,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology, size: 48, color: iconColor),
            SizedBox(width: dialogContext.spacing.smMd),
            Flexible(child: Text(l10n.appTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.version_label(packageInfo.version),
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyLarge?.copyWith(color: iconColor),
            ),
            SizedBox(height: dialogContext.spacing.xs),
            Text(
              l10n.build_label(packageInfo.buildNumber),
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyLarge?.copyWith(color: iconColor),
            ),
            SizedBox(height: dialogContext.spacing.sm),
            Text(
              l10n.profile_about_subtitle,
              style: Theme.of(
                dialogContext,
              ).textTheme.bodyLarge?.copyWith(color: iconColor),
            ),
          ],
        ),
        actions: [
          AdaptiveButton(
            style: AdaptiveButtonStyle.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.ok),
          ),
        ],
      );
    },
  );
}

void showAppearanceDialog(BuildContext context) {
  showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (dialogContext, ref, _) {
          final currentCode = ref.watch(themeModeCodeProvider);
          final l10n = dialogContext.l10n;
          final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

          return AppDialog(
            maxWidth: 720,
            title: Text(l10n.appearance_title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveSegmentedControl<String>(
                  key: const Key('profile_appearance_segmented_button'),
                  segments: {
                    kThemeModeSystem: Text(l10n.theme_mode_follow_system),
                    kThemeModeLight: Text(l10n.theme_mode_light),
                    kThemeModeDark: Text(l10n.theme_mode_dark),
                  },
                  selected: currentCode,
                  onChanged: (value) async {
                    if (value == currentCode) return;
                    final modeName = switch (value) {
                      kThemeModeSystem => l10n.theme_mode_follow_system,
                      kThemeModeLight => l10n.theme_mode_light,
                      _ => l10n.theme_mode_dark,
                    };
                    await ref
                        .read(themeModeProvider.notifier)
                        .setThemeModeCode(value);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      showTopFloatingNotice(
                        context,
                        message: l10n.theme_mode_changed(modeName),
                      );
                    }
                  },
                ),
                SizedBox(height: dialogContext.spacing.md),
                Text(
                  l10n.theme_mode_subtitle,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodySmall?.copyWith(color: iconColor),
                ),
              ],
            ),
            actions: [
              AdaptiveButton(
                style: AdaptiveButtonStyle.text,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      );
    },
  );
}

void showLogoutDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  showAppDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AppDialog(
        maxWidth: 720,
        title: Text(l10n.profile_logout_title),
        content: Text(l10n.profile_logout_message),
        actions: [
          AdaptiveButton(
            style: AdaptiveButtonStyle.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          AdaptiveButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                final l10n = context.l10n;
                showTopFloatingNotice(
                  context,
                  message: l10n.profile_logged_out,
                );
              }
            },
            child: Text(l10n.logout),
          ),
        ],
      );
    },
  );
}
