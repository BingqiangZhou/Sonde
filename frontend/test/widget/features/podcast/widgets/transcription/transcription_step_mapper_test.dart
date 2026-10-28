import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/podcast/presentation/widgets/transcription/transcription_step_mapper.dart';

void main() {
  group('transcription step mapper', () {
    test('maps boundary progress to current step number', () {
      expect(transcriptionCurrentStepNumber(0), 0);
      expect(transcriptionCurrentStepNumber(5), 1);
      expect(transcriptionCurrentStepNumber(20), 2);
      expect(transcriptionCurrentStepNumber(35), 3);
      expect(transcriptionCurrentStepNumber(45), 4);
      expect(transcriptionCurrentStepNumber(95), 5);
      expect(transcriptionCurrentStepNumber(100), 5);
    });

    test('maps boundary progress to active step index', () {
      expect(transcriptionActiveStepIndex(0), 0);
      expect(transcriptionActiveStepIndex(5), 0);
      expect(transcriptionActiveStepIndex(20), 1);
      expect(transcriptionActiveStepIndex(35), 2);
      expect(transcriptionActiveStepIndex(45), 3);
      expect(transcriptionActiveStepIndex(95), 4);
      expect(transcriptionActiveStepIndex(100), 4);
    });

    test('maps step statuses correctly at each boundary', () {
      expect(_stepStatuses(0), <TranscriptionStepStatus>[
        TranscriptionStepStatus.current,
        TranscriptionStepStatus.pending,
        TranscriptionStepStatus.pending,
        TranscriptionStepStatus.pending,
        TranscriptionStepStatus.pending,
      ]);
      expect(_stepStatuses(20), <TranscriptionStepStatus>[
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.current,
        TranscriptionStepStatus.pending,
        TranscriptionStepStatus.pending,
        TranscriptionStepStatus.pending,
      ]);
      expect(_stepStatuses(35), <TranscriptionStepStatus>[
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.current,
        TranscriptionStepStatus.pending,
        TranscriptionStepStatus.pending,
      ]);
      expect(_stepStatuses(45), <TranscriptionStepStatus>[
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.current,
        TranscriptionStepStatus.pending,
      ]);
      expect(_stepStatuses(95), <TranscriptionStepStatus>[
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.completed,
        TranscriptionStepStatus.current,
      ]);
      expect(_stepStatuses(100), _stepStatuses(95));
    });
  });
}

List<TranscriptionStepStatus> _stepStatuses(double progress) {
  return List<TranscriptionStepStatus>.generate(
    5,
    (index) => transcriptionStepStatusAt(progress, index),
  );
}
