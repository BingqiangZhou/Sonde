# Flutter Test Architecture Guide

## Overview

This document describes the actual test architecture of the Flutter app
(`frontend/`), so new tests follow the same conventions instead of an
aspirational system.

Current shape: ~45 unit tests (`test/unit/`), ~45 widget tests
(`test/widget/`), integration tests (`test/integration/`), and one
API-contract test (`test/core/network/api_contract_test.dart`) that verifies
request shapes against the backend contract without a live server.

## Test Structure

```
test/
├── core/                    # Core-layer tests (network, database, storage)
│   └── network/api_contract_test.dart
├── features/                # Feature-mirrored unit/widget tests
├── helpers/                 # Hand-rolled fakes and behavior libraries
│   ├── mock_audio_player_notifier.dart
│   ├── mock_local_storage_service.dart
│   ├── podcast_episode_detail_helper.dart
│   └── podcast_list_page_helper.dart
├── integration/             # Cross-layer flows (e.g. auth)
├── test_helpers.dart        # testAppWithRouter + tapAndSettle
├── unit/                    # Unit tests (providers, services, utils)
└── widget/                  # Widget tests (pages, components)
```

## Mock Strategy

There is **no codegen mock system** (no `test/mocks/`, no
`@GenerateMocks`). Two complementary techniques are used instead:

### 1. Hand-rolled fakes (`test/helpers/`)

Fakes implement the real interface with in-memory behavior. Prefer these
when tests need stateful or behavioral semantics that stubbing cannot
express well.

- `MockLocalStorageService implements LocalStorageService` — in-memory
  key-value store with `presetString` for pre-seeding.
- `MockAudioPlayerNotifier extends AudioPlayerNotifier` — records
  `lastPlayedEpisode` using the notifier's `@visibleForTesting` seams.
- `podcast_list_page_helper.dart` — fake RSS/iTunes services,
  `DelayedSubscriptionNotifier`, etc., modeling load latencies and
  reordering behavior.
- Drift DAO tests use `AppDatabase(NativeDatabase.memory())` directly;
  provider tests override `appDatabaseProvider` with an in-memory database.

### 2. mocktail (targeted, ~3 files)

Use `Mock` from mocktail only for wide interfaces where stubbing individual
methods is more concise than a fake, e.g. `_MockAdapter implements
HttpClientAdapter` for Dio, `_MockSecureStorage extends Mock implements
FlutterSecureStorage` in `token_refresh_service_test.dart`. Prefer narrow
hand-rolled fakes for anything a test interacts with statefully.

### Global test config

`flutter_test_config.dart` silences `AppLogger` during tests and restores it
afterwards — do not add per-test logger mocking.

## Widget Testing Conventions

- Pages are `ConsumerWidget`/`ConsumerStatefulWidget`; tests wrap them via
  `testAppWithRouter` from `test/test_helpers.dart` (localized
  `MaterialApp.router` with `appLocalizationsDelegates`).
- `tapAndSettle` wraps `tap` + `pumpAndSettle` for actions that trigger
  animations or async providers.
- Override providers at the `ProviderScope` (repository providers,
  `appDatabaseProvider`, `localStorageServiceProvider`) rather than reaching
  into notifier internals.
- Use production seams: `debugReplaceManagedResources` and
  `@visibleForTesting` constructors exist precisely for tests (see
  `audio_player_notifier_lifecycle_test.dart` for the pattern).

### Required scenarios for new pages

- Renders required UI components and empty state
- Loading → success transition with visible data
- Error state (use repository fakes that throw)
- Navigation (keys + GoRouter argument extraction)

## Running Tests

```bash
cd frontend

# Full suite
flutter test

# Targeted
flutter test test/unit/features/podcast/providers/
flutter test test/widget/features/profile/

# With coverage
flutter test --coverage
```

No mock generation step exists or is needed; there is nothing to run via
build_runner before tests (codegen covers only production `.g.dart` files,
which are committed).

## Troubleshooting

1. **`Bad state: No ProviderScope found`** — a `Consumer` widget was pumped
   without `ProviderScope`; wrap the harness and override
   `localStorageServiceProvider` with `MockLocalStorageService`.
2. **`Binding has not yet been initialized`** — a unit test touched a
   platform plugin (e.g. real `driftDatabase` via `appDatabaseProvider`);
   override the provider with an in-memory implementation.
3. **Stale async responses** — provider tests that await real timers:
   inject test doubles via the notifier's testing seams instead of
   `Future.delayed`.
4. **Navigation test failures** — verify typed `Args.extractFromState`
   parsing in `features/podcast/presentation/navigation/` and route keys.

## Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Riverpod Testing Guide](https://riverpod.dev/docs/cookbooks/testing)
- [mocktail](https://pub.dev/packages/mocktail)
