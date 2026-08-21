import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sonde/core/constants/app_radius.dart';
import 'package:sonde/core/constants/app_spacing.dart';
import 'package:sonde/core/localization/app_localizations_extension.dart';
import 'package:sonde/features/pairing/domain/pairing_payload.dart';
import 'package:sonde/features/pairing/presentation/providers/pairing_provider.dart';

/// First-run backend pairing: scan the admin QR (mobile) or paste
/// host + API key manually (desktop fallback).
class PairingPage extends ConsumerStatefulWidget {
  const PairingPage({super.key});

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  final _hostController = TextEditingController();
  final _keyController = TextEditingController();
  bool get _showScanner =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void dispose() {
    _hostController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _submit(PairingPayload payload) async {
    final ok = await ref.read(pairingProvider.notifier).pair(payload);
    if (!mounted) return;
    if (ok) {
      context.go('/feed');
    }
  }

  Future<void> _submitManual() async {
    final payload = PairingPayload.tryParse(
      '${_hostController.text.trim()}|${_keyController.text.trim()}',
    );
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pairingInvalidInput)),
      );
      return;
    }
    await _submit(payload);
  }

  void _onScan(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    final payload = PairingPayload.tryParse(raw);
    if (payload == null) return; // keep scanning non-pairing codes
    _submit(payload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(pairingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairingTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.pairingSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: context.spacing.lg),
                  if (_showScanner) ...[
                    ClipRRect(
                      borderRadius: AppRadius.lgRadius,
                      child: SizedBox(
                        height: 260,
                        child: MobileScanner(onDetect: _onScan),
                      ),
                    ),
                    SizedBox(height: context.spacing.md),
                    Text(
                      l10n.pairingScanHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.spacing.lg),
                  ],
                  TextField(
                    controller: _hostController,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.pairingHostLabel,
                      hintText: 'http://192.168.1.5:8000',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: context.spacing.md),
                  TextField(
                    controller: _keyController,
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.pairingKeyLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: context.spacing.lg),
                  FilledButton(
                    onPressed: state.isVerifying ? null : _submitManual,
                    child: state.isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l10n.pairingConnect),
                  ),
                  if (state.error != null) ...[
                    SizedBox(height: context.spacing.md),
                    Text(
                      '${l10n.pairingFailed}\n${state.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  SizedBox(height: context.spacing.md),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(l10n.pairingLoginInstead),
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
