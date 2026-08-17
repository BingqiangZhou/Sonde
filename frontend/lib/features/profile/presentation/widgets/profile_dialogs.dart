import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/constants/breakpoints.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/localization/locale_provider.dart';
import 'package:sonde/core/platform/platform_helper.dart';
import 'package:sonde/core/theme/theme_provider.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_dialog_helper.dart';
import 'package:sonde/core/widgets/top_floating_notice.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';

// Profile page dialogs, extracted from profile_page.dart. These do not use
// showAppDialog because profile dialogs need constrained width, which
// showAppDialog does not support. See app_dialog_helper.dart.

double _dialogMaxWidth(BuildContext context) {
  return ResponsiveDialogHelper.maxWidth(
    context,
    desktopMaxWidth: 720,
    mobileHorizontalMargin: context.spacing.xs,
  );
}

EdgeInsets _dialogInsetPadding(BuildContext context) {
  if (context.isMobile) {
    return EdgeInsets.symmetric(
      horizontal: context.spacing.xs,
      vertical: context.spacing.md,
    );
  }
  return EdgeInsets.zero;
}

Future<T?> showProfileDialog<T>(
  BuildContext context, {
  required Widget Function(BuildContext dialogContext) builder,
  bool barrierDismissible = true,
}) {
  if (PlatformHelper.isApple(context)) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _dialogMaxWidth(context)),
          child: Material(
            color: Colors.transparent,
            child: builder(dialogContext),
          ),
        ),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: _dialogInsetPadding(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _dialogMaxWidth(context)),
        child: builder(dialogContext),
      ),
    ),
  );
}

Widget buildProfileDialogContent({
  required BuildContext dialogContext,
  required Widget title,
  required Widget content,
  required List<Widget> actions,
}) {
  final isIOS = PlatformHelper.isApple(dialogContext);
  final theme = Theme.of(dialogContext);

  return Material(
    color: isIOS
        ? CupertinoColors.systemBackground.resolveFrom(dialogContext)
        : theme.colorScheme.surfaceContainerHighest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isIOS ? 14 : 28),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(dialogContext.spacing.lg, isIOS ? AppSpacing.mdLg : AppSpacing.lg, dialogContext.spacing.lg, isIOS ? AppSpacing.sm : AppSpacing.md),
          child: Align(
            alignment: isIOS ? Alignment.center : AlignmentDirectional.centerStart,
            child: DefaultTextStyle(
              style: isIOS
                  ? CupertinoTheme.of(dialogContext)
                      .textTheme
                      .textStyle
                      .copyWith(fontSize: theme.textTheme.titleLarge?.fontSize, fontWeight: FontWeight.w600)
                  : theme.textTheme.titleLarge!,
              child: title,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(dialogContext.spacing.lg, 0, dialogContext.spacing.lg, dialogContext.spacing.md),
          child: Align(
            alignment: isIOS ? Alignment.center : AlignmentDirectional.centerStart,
            child: DefaultTextStyle(
              style: isIOS
                  ? CupertinoTheme.of(dialogContext)
                      .textTheme
                      .textStyle
                      .copyWith(fontSize: theme.textTheme.bodyMedium?.fontSize)
                  : theme.textTheme.bodyMedium!,
              child: content,
            ),
          ),
        ),
        if (actions.isNotEmpty) ...[
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          if (isIOS)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions
                    .map((a) => Expanded(child: a))
                    .toList(),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(dialogContext.spacing.md, dialogContext.spacing.smMd, dialogContext.spacing.md, dialogContext.spacing.smMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
        ],
      ],
    ),
  );
}

void showEditProfileDialog(BuildContext context) {
  final l10n = context.l10n;
  showProfileDialog<void>(
    context,
    builder: (dialogContext) {
      return buildProfileDialogContent(
        dialogContext: dialogContext,
        title: Text(l10n.profile_edit_profile),
        content: Text(l10n.profile_edit_coming_soon_subtitle),
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

void showSecurityDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  showProfileDialog<void>(
    context,
    builder: (dialogContext) {
      final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
      return buildProfileDialogContent(
        dialogContext: dialogContext,
        title: Text(l10n.profile_security),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdaptiveListTile(
              leading: Icon(Icons.password, color: iconColor),
              title: Text(l10n.profile_change_password),
              trailing: Icon(
                PlatformHelper.isApple(dialogContext)
                    ? CupertinoIcons.chevron_right
                    : Icons.chevron_right,
                color: iconColor,
              ),
              onTap: () {
                Navigator.of(dialogContext).pop();
                showChangePasswordDialog(context, ref);
              },
            ),
            AdaptiveListTile(
              leading: Icon(Icons.fingerprint, color: iconColor),
              title: Text(l10n.profile_biometric_auth),
              subtitle: Text(
                l10n.profile_biometric_coming_soon,
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Switch.adaptive(
                value: false,
                onChanged: null,
              ),
            ),
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

void showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final authState = ref.read(authProvider);
  final userEmail = authState.user?.email;

  showProfileDialog<void>(
    context,
    builder: (dialogContext) {
      return buildProfileDialogContent(
        dialogContext: dialogContext,
        title: Text(l10n.profile_password_change_title),
        content: Text(
          userEmail != null
              ? l10n.profile_password_reset_email_description(userEmail)
              : l10n.profile_password_change_failed,
        ),
        actions: [
          AdaptiveButton(
            style: AdaptiveButtonStyle.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          if (userEmail != null)
            AdaptiveButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await ref
                      .read(authProvider.notifier)
                      .forgotPassword(userEmail);
                  if (context.mounted) {
                    final l10n = context.l10n;
                    showTopFloatingNotice(
                      context,
                      message: l10n.profile_password_reset_email_sent,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    final l10n = context.l10n;
                    showTopFloatingNotice(
                      context,
                      message: l10n.profile_password_change_failed,
                    );
                  }
                }
              },
              child: Text(l10n.profile_send_reset_link),
            ),
        ],
      );
    },
  );
}

void showLanguageDialog(BuildContext context) {
  showProfileDialog<void>(
    context,
    builder: (dialogContext) {
      return Consumer(
        builder: (dialogContext, ref, _) {
          final currentCode = ref.watch(localeCodeProvider);
          final l10n = dialogContext.l10n;
          final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

          return buildProfileDialogContent(
            dialogContext: dialogContext,
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

  showProfileDialog<void>(
    context,
    builder: (dialogContext) {
      final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);
      return buildProfileDialogContent(
        dialogContext: dialogContext,
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
  showProfileDialog<void>(
    context,
    builder: (dialogContext) {
      return Consumer(
        builder: (dialogContext, ref, _) {
          final currentCode = ref.watch(themeModeCodeProvider);
          final l10n = dialogContext.l10n;
          final iconColor = ResponsiveDialogHelper.iconColor(dialogContext);

          return buildProfileDialogContent(
            dialogContext: dialogContext,
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
  showProfileDialog<void>(
    context,
    builder: (dialogContext) {
      return buildProfileDialogContent(
        dialogContext: dialogContext,
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
