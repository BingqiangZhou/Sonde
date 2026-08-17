import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/app/config/app_config.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/platform/adaptive_haptic.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/core/widgets/top_floating_notice.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/features/auth/presentation/widgets/password_requirement_item.dart';
import 'package:sonde/features/auth/presentation/widgets/password_text_field.dart';
import 'package:sonde/shared/widgets/custom_text_field.dart';
import 'package:sonde/shared/widgets/loading_widget.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearFieldErrors() {
    ref.read(authProvider.notifier).clearFieldErrors();
  }

  Future<void> _register() async {
    final l10n = context.l10n;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    if (!_agreeToTerms) {
      showTopFloatingNotice(
        context,
        message: l10n.auth_agree_terms,
        isError: true,
      );
      return;
    }

    try {
      if (_rememberMe) {
        final storage = ref.read(secureStorageProvider);
        await storage.save(AppConstants.savedUsernameKey, _emailController.text.trim());
        await storage.save(AppConstants.savedPasswordKey, _passwordController.text);
      } else {
        final storage = ref.read(secureStorageProvider);
        await storage.remove(AppConstants.savedUsernameKey);
        await storage.remove(AppConstants.savedPasswordKey);
      }
    } catch (_) {
      // Storage failure should not block registration.
    }

    ref.read(authProvider.notifier).register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final fieldErrors = ref.watch(authProvider.select((s) => s.fieldErrors));

    // Listen for auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      final wasAuthenticated = previous?.isAuthenticated ?? false;
      final isAuthenticated = next.isAuthenticated;

      if (isAuthenticated && !wasAuthenticated) {
        AdaptiveHaptic.notificationSuccess();
        context.go('/feed');
      } else if (next.error != null &&
          next.error != previous?.error &&
          next.fieldErrors == null) {
        if (mounted) {
          // Localize the known business conflict; other errors pass through.
          final message = next.error == 'Email already registered'
              ? l10n.auth_email_registered
              : next.error!;
          showTopFloatingNotice(context, message: message, isError: true);
        }
      }
    });

    return AdaptiveScaffold(
      child: LoadingOverlay(
        isLoading: isLoading,
        child: AuthShell(
          title: l10n.auth_create_account,
          subtitle: l10n.auth_sign_up_subtitle,
          header: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: AppRadius.xlRadius,
            ),
            child: Icon(
              Icons.person_add,
              size: 30,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Auto-generated nickname hint — no name field at signup
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: AppRadius.smRadius,
                  ),
                  padding: EdgeInsets.all(context.spacing.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: context.spacing.xs),
                      Expanded(
                        child: Text(
                          l10n.auth_name_autogen_hint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: context.spacing.smMd),

                // Email field
                CustomTextField(
                  controller: _emailController,
                  label: l10n.auth_email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  autofillHints: const [AutofillHints.email],
                  onChanged: (value) {
                    _clearFieldErrors();
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.auth_enter_email;
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return l10n.auth_enter_valid_email;
                    }
                    return null;
                  },
                  errorText: fieldErrors?['email'],
                ),

                SizedBox(height: context.spacing.smMd),

                // Password field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PasswordTextField(
                      controller: _passwordController,
                      label: l10n.auth_password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      toggleButtonKey: const Key('password_visibility_toggle'),
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      onChanged: (value) => _clearFieldErrors(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.auth_enter_password;
                    }
                    if (value.length < 8) {
                      return l10n.auth_password_too_short;
                    }
                    if (value.length > 72) {
                      return l10n.validation_too_long;
                    }
                    if (!value.contains(RegExp('[A-Z]'))) {
                          return l10n.auth_password_requirement_uppercase;
                        }
                        if (!value.contains(RegExp('[a-z]'))) {
                          return l10n.auth_password_requirement_lowercase;
                        }
                        if (!value.contains(RegExp('[0-9]'))) {
                          return l10n.auth_password_requirement_number;
                        }
                        return null;
                      },
                      errorText: fieldErrors?['password'],
                    ),
                    SizedBox(height: context.spacing.xs),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: AppRadius.smRadius,
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
                      ),
                      padding: EdgeInsets.all(context.spacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l10n.auth_password}:',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          SizedBox(height: context.spacing.xs),
                          PasswordRequirementItem(
                            text: l10n.auth_password_too_short,
                            isValid: _passwordController.text.length >= 8,
                          ),
                          PasswordRequirementItem(
                            text: l10n.auth_password_req_uppercase_short,
                            isValid: _passwordController.text.contains(
                              RegExp('[A-Z]'),
                            ),
                          ),
                          PasswordRequirementItem(
                            text: l10n.auth_password_req_lowercase_short,
                            isValid: _passwordController.text.contains(
                              RegExp('[a-z]'),
                            ),
                          ),
                          PasswordRequirementItem(
                            text: l10n.auth_password_req_number_short,
                            isValid: _passwordController.text.contains(
                              RegExp('[0-9]'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.spacing.smMd),

                // Confirm password field
                PasswordTextField(
                  controller: _confirmPasswordController,
                  label: l10n.auth_confirm_password,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onToggleVisibility: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.auth_enter_password;
                    }
                    if (value != _passwordController.text) {
                      return l10n.auth_passwords_not_match;
                    }
                    return null;
                  },
                ),

                SizedBox(height: context.spacing.md),

                // Remember me checkbox
                Row(
                  children: [
                    AdaptiveSwitch(
                      value: _rememberMe,
                      semanticLabel: l10n.auth_remember_me,
                      onChanged: (value) async {
                        setState(() {
                          _rememberMe = value;
                        });
                        if (!_rememberMe) {
                          final storage = ref.read(secureStorageProvider);
                          await storage.remove(AppConstants.savedUsernameKey);
                          await storage.remove(AppConstants.savedPasswordKey);
                        }
                      },
                    ),
                    Text(l10n.auth_remember_me),
                  ],
                ),

                SizedBox(height: context.spacing.sm),

                // Terms and conditions
                Row(
                  children: [
                    AdaptiveSwitch(
                      value: _agreeToTerms,
                      semanticLabel: l10n.auth_terms_and_conditions,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value;
                        });
                      },
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: l10n.auth_agree_prefix,
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  // TODO: Show terms and conditions
                                },
                                child: Text(
                                  l10n.auth_terms_and_conditions,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                            TextSpan(text: l10n.auth_and),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  // TODO: Show privacy policy
                                },
                                child: Text(
                                  l10n.auth_privacy_policy,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: context.spacing.lg),

                // Register button
                AdaptiveButton(
                  key: const Key('register_button'),
                  onPressed: isLoading ? null : _register,
                  isLoading: isLoading,
                  child: Text(l10n.auth_create_account),
                ),

                SizedBox(height: context.spacing.md),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.auth_already_have_account,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: context.spacing.xs),
                    AdaptiveButton(
                      style: AdaptiveButtonStyle.text,
                      onPressed: () => context.go('/login'),
                      child: Text(
                        l10n.auth_sign_in_link,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
