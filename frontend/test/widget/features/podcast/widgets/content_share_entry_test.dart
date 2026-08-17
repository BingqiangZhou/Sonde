import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonde/core/localization/app_localizations.dart';
import 'package:sonde/core/localization/l10n_delegates.dart';
import 'package:sonde/core/theme/app_theme.dart';
import 'package:sonde/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:sonde/features/podcast/presentation/widgets/transcript_display_widget.dart';

void main() {
  testWidgets('Transcript widget has no share-all entry', (tester) async {
    final transcription = PodcastTranscriptionResponse(
      id: 1,
      episodeId: 1,
      status: 'completed',
      transcriptContent: 'This is a transcript sentence.',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TranscriptDisplayWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              transcription: transcription,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Share All'), findsNothing);
    expect(find.text('Share All'), findsNothing);
  });
}
