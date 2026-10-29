import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/core/theme/app_colors.dart';
import 'package:sonde/core/widgets/adaptive/adaptive.dart';
import 'package:sonde/core/widgets/app_shells.dart';
import 'package:sonde/core/widgets/top_floating_notice.dart';
import 'package:sonde/features/auth/presentation/providers/auth_provider.dart';
import 'package:sonde/shared/widgets/custom_text_field.dart';
import 'package:sonde/shared/widgets/loading_widget.dart';
import 'package:sonde/core/theme/app_opacity.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  ProviderSubscription<AuthState>? _authSubscription;


  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthState>(authProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      final previousLoading = previous?.isLoading ?? false;
      final completedForgotPassword =
          previousLoading &&
          !next.isLoading &&
          next.error == null &&
          (previous?.currentOperation == AuthOperation.forgotPassword ||
              next.currentOperation == AuthOperation.forgotPassword);

      if (completedForgotPassword && !_emailSent) {
        setState(() {
          _emailSent = true;
        });
        return;
      }

      final error = next.error;
      if (error != null && error.isNotEmpty) {
        showTopFloatingNotice(context, message: error, isError: true);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _emailController.dispose();
    super.dispose();
  }

  void _submitForgotPassword() {
    final formState = _formKey.currentState;
    if (formState != null && formState.validate()) {
      ref
          .read(authProvider.notifier)
          .forgotPassword(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {

    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));

    final forgotTitle =
        context.l10n.auth_forgot_password;
    final successTitle =
        context.l10n.auth_reset_email_sent;

    return AdaptiveScaffold(
      child: LoadingOverlay(
        isLoading: isLoading,
        child: AuthShell(
          title: _emailSent ? successTitle : forgotTitle,
          subtitle: _emailSent
              ? context.l10n.auth_reset_email_sent_to(
                  _emailController.text.trim(),
                )
              : context.l10n.auth_reset_password_subtitle,
          header: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Icon(Icons.adaptive.arrow_back),
                  onPressed: () => context.go('/login'),
                ),
              ),
              SizedBox(height: context.spacing.sm),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _emailSent
                      ? AppColors.accentWarm.withValues(alpha: AppOpacity.faint)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: AppOpacity.faint),
                  borderRadius: AppRadius.xlRadius,
                ),
                child: Icon(
                  _emailSent ? Icons.check_circle_outline : Icons.lock_reset,
                  size: 40,
                  color: _emailSent
                      ? AppColors.accentWarm
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          child: _emailSent ? _buildSuccessContent(context) : _buildFormContent(context, isLoading),
        ),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            controller: _emailController,
            label: context.l10n.auth_email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.email_outlined),
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.l10n.auth_enter_email;
              }
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return context.l10n.auth_enter_valid_email;
              }
              return null;
            },
          ),
          SizedBox(height: context.spacing.xl),
          AdaptiveButton(
            key: const Key('forgot_password_submit_button'),
            style: AdaptiveButtonStyle.filled,
            onPressed: isLoading ? null : _submitForgotPassword,
            child: Text(
              context.l10n.auth_send_reset_link,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.auth_check_email_fallback,
          key: const Key('forgot_password_success_message'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.spacing.xl),
        AdaptiveButton(
          key: const Key('back_to_login_button'),
          style: AdaptiveButtonStyle.outlined,
          onPressed: () => context.go('/login'),
          child: Text(
            context.l10n.auth_back_to_login,
          ),
        ),
        SizedBox(height: context.spacing.md),
        AdaptiveButton(
          key: const Key('resend_email_button'),
          style: AdaptiveButtonStyle.text,
          onPressed: () {
            setState(() {
              _emailSent = false;
            });
            ref.read(authProvider.notifier).clearError();
          },
          child: Text(
            context.l10n.auth_resend_email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
      ],
    );
  }
}
