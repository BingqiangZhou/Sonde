import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/localization/locale_provider.dart';
import 'package:personal_ai_assistant/core/platform/adaptive_haptic.dart';
import 'package:personal_ai_assistant/core/theme/theme_provider.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/profile/presentation/providers/profile_ui_providers.dart';
import 'package:personal_ai_assistant/features/profile/presentation/widgets/profile_activity_cards.dart';
import 'package:personal_ai_assistant/features/profile/presentation/widgets/profile_dialogs.dart';
import 'package:personal_ai_assistant/features/settings/presentation/widgets/update_dialog.dart';
import 'package:personal_ai_assistant/shared/widgets/server_config_dialog.dart';
import 'package:personal_ai_assistant/shared/widgets/settings_section_card.dart';

/// Material Design 3 adaptive profile page
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        // Force refresh after login to ensure fresh data from new server
        ref.read(profileStatsProvider.notifier).load(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  EdgeInsetsGeometry _profileCardMargin(BuildContext context) =>
      context.isMobile
      ? EdgeInsets.symmetric(horizontal: context.spacing.xs)
      : EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = ref.watch(authProvider.select((s) => s.user));
    final theme = Theme.of(context);
    final compactProfileLayout = MediaQuery.sizeOf(context).height < 700;

    return ContentShell(
      title: l10n.profile,
      subtitle: '',
      roundedViewport: true,
      trailing: _buildUserMenu(context, user, theme, l10n),
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(bottom: context.spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileActivityCards(),
              SizedBox(height: compactProfileLayout ? context.spacing.sm : context.spacing.md),
              _buildSettingsContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    final l10n = context.l10n;
    final isMobile = context.isMobile;

    final accountItems = <_SettingsItemConfig>[
      _SettingsItemConfig(
        icon: Icons.shield,
        title: l10n.profile_security,
        subtitle: l10n.profile_security_subtitle,
        onTap: () => showSecurityDialog(context, ref),
      ),
      _SettingsItemConfig(
        icon: Icons.notifications,
        title: l10n.profile_notifications,
        subtitle: l10n.profile_notifications_subtitle,
        trailing: Consumer(
          builder: (context, ref, _) {
            final theme = Theme.of(context);
            final notificationsEnabled = ref.watch(notificationPreferenceProvider);
            return Switch.adaptive(
              key: const Key('profile_notifications_switch'),
              value: notificationsEnabled,
              activeThumbColor: theme.colorScheme.surface,
              inactiveThumbColor: theme.colorScheme.surface,
              activeTrackColor: theme.colorScheme.onSurfaceVariant,
              inactiveTrackColor: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.30,
              ),
              onChanged: (value) {
                ref.read(notificationPreferenceProvider.notifier).setEnabled(value);
              },
            );
          },
        ),
      ),
    ];

    final supportItems = <_SettingsItemConfig>[
      _SettingsItemConfig(
        icon: Icons.dns,
        title: l10n.backend_api_server_config,
        subtitle: l10n.backend_api_url_label,
        onTap: () => _showServerConfigDialog(context),
      ),
      _SettingsItemConfig(
        icon: Icons.cleaning_services,
        title: l10n.profile_cache_management,
        subtitle: l10n.profile_cache_management_subtitle,
        tileKey: const Key('profile_clear_cache_item'),
        onTap: () => context.push('/profile/cache'),
      ),
      _SettingsItemConfig(
        icon: Icons.download,
        title: l10n.profile_downloads,
        subtitle: l10n.profile_downloads_subtitle,
        onTap: () => context.push('/profile/downloads'),
      ),
    ];

    final aboutItems = <_SettingsItemConfig>[
      _SettingsItemConfig(
        icon: Icons.system_update_alt,
        title: l10n.update_check_updates,
        subtitle: l10n.update_auto_check,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showUpdateCheckDialog(context),
      ),
      _SettingsItemConfig(
        icon: Icons.info_outline,
        title: l10n.version,
        subtitle: ref.watch(appVersionProvider),
        trailing: const Icon(Icons.chevron_right),
        tileKey: const Key('profile_version_item'),
        onTap: () => showProfileAboutDialog(context),
      ),
    ];

    final preferencesSection = SettingsSectionCard(
      title: l10n.preferences,
      cardMargin: _profileCardMargin(context),
      children: [
        _buildLanguageSettingsItem(context),
        _buildAppearanceSettingsItem(context),
      ],
    );

    if (isMobile) {
      return Column(
        children: [
          _buildSettingsSectionFromConfigs(
            context,
            l10n.profile_account_settings,
            accountItems,
          ),
          SizedBox(height: context.spacing.lg),
          preferencesSection,
          SizedBox(height: context.spacing.lg),
          _buildSettingsSectionFromConfigs(
            context,
            l10n.profile_support_section,
            supportItems,
          ),
          SizedBox(height: context.spacing.lg),
          _buildSettingsSectionFromConfigs(context, l10n.about, aboutItems),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSettingsSectionFromConfigs(
                context,
                l10n.profile_account_settings,
                accountItems,
              ),
            ),
            SizedBox(width: context.spacing.lg),
            Expanded(child: preferencesSection),
          ],
        ),
        SizedBox(height: context.spacing.lg),
        _buildSettingsSectionFromConfigs(
          context,
          l10n.profile_support_section,
          supportItems,
        ),
        SizedBox(height: context.spacing.lg),
        _buildSettingsSectionFromConfigs(context, l10n.about, aboutItems),
      ],
    );
  }

  Widget _buildSettingsSectionFromConfigs(
    BuildContext context,
    String title,
    List<_SettingsItemConfig> items,
  ) {
    return SettingsSectionCard(
      title: title,
      cardMargin: _profileCardMargin(context),
      children: items
          .map((item) => _buildSettingsItemFromConfig(context, item))
          .toList(),
    );
  }

  Widget _buildSettingsItemFromConfig(
    BuildContext context,
    _SettingsItemConfig item,
  ) {
    return _buildSettingsItem(
      context,
      tileKey: item.tileKey,
      icon: item.icon,
      title: item.title,
      subtitle: item.subtitle,
      trailing: item.trailing,
      onTap: item.onTap,
    );
  }

  Widget _buildLanguageSettingsItem(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentCode = ref.watch(localeCodeProvider);
        final l10n = context.l10n;
        final languageName = switch (currentCode) {
          kLanguageSystem => l10n.languageFollowSystem,
          kLanguageChinese => l10n.languageChinese,
          _ => l10n.languageEnglish,
        };

        return _buildSettingsItem(
          context,
          icon: Icons.language,
          title: l10n.language,
          subtitle: languageName,
          onTap: () => showLanguageDialog(context),
        );
      },
    );
  }

  Widget _buildAppearanceSettingsItem(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentCode = ref.watch(themeModeCodeProvider);
        final l10n = context.l10n;
        final themeModeName = switch (currentCode) {
          kThemeModeSystem => l10n.theme_mode_follow_system,
          kThemeModeLight => l10n.theme_mode_light,
          _ => l10n.theme_mode_dark,
        };

        return _buildSettingsItem(
          context,
          icon: Icons.palette_outlined,
          title: l10n.appearance_title,
          subtitle: themeModeName,
          onTap: () => showAppearanceDialog(context),
        );
      },
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon, required String title, required String subtitle, Key? tileKey,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return AdaptiveListTile(
      key: tileKey,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
  void _showServerConfigDialog(BuildContext context) {
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ServerConfigDialog(),
    );
  }

  void _showUpdateCheckDialog(BuildContext context) {
    ManualUpdateCheckDialog.show(context);
  }

  Widget _buildUserMenu(
    BuildContext context,
    User? user,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.onSurfaceVariant,
      child: Text(
        (user?.displayName ?? l10n.profile_guest_user).characters.firstOrNull?.toUpperCase() ?? '?',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.surface,
        ),
      ),
    );

    return Semantics(
      button: true,
      hint: 'User menu',
      child: GestureDetector(
        key: const Key('profile_user_menu_button'),
        onTap: () {
          AdaptiveHaptic.lightImpact();
          _showUserMenu(context, user, l10n);
        },
        child: avatar,
      ),
    );
  }

  void _showUserMenu(
    BuildContext context,
    User? user,
    AppLocalizations l10n,
  ) {
    showAdaptiveActionSheet(
      context: context,
      title: Text(user?.displayName ?? l10n.profile_guest_user),
      message: Text(user?.email ?? l10n.profile_please_login),
      actions: [
        AdaptiveActionSheetAction(
          key: const Key('profile_user_menu_item_edit'),
          onPressed: () => showEditProfileDialog(context),
          child: Text(l10n.profile_edit_profile),
        ),
        AdaptiveActionSheetAction(
          key: const Key('profile_user_menu_item_logout'),
          onPressed: () => showLogoutDialog(context, ref),
          isDestructive: true,
          child: Text(l10n.logout),
        ),
      ],
      cancelWidget: Text(l10n.cancel),
    );
  }
}

class _SettingsItemConfig {
  const _SettingsItemConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tileKey,
    this.trailing,
    this.onTap,
  });

  final Key? tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
}
