import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonde/core/network/exceptions/network_exceptions.dart';
import 'package:sonde/core/services/app_update_service.dart';
import 'package:sonde/shared/models/github_release.dart';

/// App Update State / 应用更新状态
class AppUpdateState {

  const AppUpdateState({
    this.isLoading = false,
    this.latestRelease,
    this.hasUpdate = false,
    this.error,
    this.currentVersion = '0.0.0',
    this.platformAsset,
  });
  /// Whether a check is in progress
  final bool isLoading;

  /// The latest available release (null if up to date)
  final GitHubRelease? latestRelease;

  /// Whether an update is available
  final bool hasUpdate;

  /// Error message if check failed
  final String? error;

  /// Current app version
  final String currentVersion;

  /// The matched asset for the current platform (null if no match)
  final GitHubAsset? platformAsset;

  /// Whether the current platform has a downloadable asset
  bool get hasPlatformAsset => platformAsset != null;

  AppUpdateState copyWith({
    bool? isLoading,
    GitHubRelease? latestRelease,
    bool? hasUpdate,
    String? error,
    String? currentVersion,
    GitHubAsset? platformAsset,
    bool clearPlatformAsset = false,
  }) {
    return AppUpdateState(
      isLoading: isLoading ?? this.isLoading,
      latestRelease: latestRelease ?? this.latestRelease,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      error: error,
      currentVersion: currentVersion ?? this.currentVersion,
      platformAsset: clearPlatformAsset
          ? null
          : (platformAsset ?? this.platformAsset),
    );
  }
}

/// App Update Notifier / 应用更新通知器
class AppUpdateNotifier extends Notifier<AppUpdateState> {
  AppUpdateService get _updateService => ref.read(appUpdateServiceProvider);

  @override
  AppUpdateState build() {
    // package_info_plus has no sync API; the real version arrives via
    // _loadActualVersion() shortly after build.
    _loadActualVersion();
    return const AppUpdateState();
  }

  Future<void> _loadActualVersion() async {
    final actualVersion = await AppUpdateService.getCurrentVersion();
    if (!ref.mounted) return;
    state = state.copyWith(currentVersion: actualVersion);
  }

  /// Check for updates
  ///
  /// [forceRefresh] - if true, bypass cache and fetch from GitHub
  /// [includePrerelease] - if true, include pre-release versions
  Future<void> checkForUpdates({
    bool forceRefresh = false,
    bool includePrerelease = false,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final release = await _updateService.checkForUpdates(
        forceRefresh: forceRefresh,
        includePrerelease: includePrerelease,
      );
      if (!ref.mounted) return;

      if (release != null) {
        final asset = _updateService.getAssetForCurrentPlatform(release);
        state = state.copyWith(
          isLoading: false,
          latestRelease: release,
          hasUpdate: true,
          platformAsset: asset,
          clearPlatformAsset: asset == null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          hasUpdate: false,
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: mapErrorMessage(e),
      );
    }
  }

  /// Skip this update version
  Future<void> skipVersion() async {
    if (state.latestRelease != null) {
      await _updateService.skipVersion(state.latestRelease!.version);
      if (!ref.mounted) return;
      state = state.copyWith(
        hasUpdate: false,
      );
    }
  }

  /// Reset state (clear update notification)
  void reset() {
    state = AppUpdateState(
      currentVersion: state.currentVersion,
    );
  }

  /// Clear skipped version (for manual update check)
  Future<void> clearSkipped() async {
    await _updateService.clearSkippedVersion();
  }

  /// Get download URL for current platform
  String? getDownloadUrl() {
    if (state.latestRelease == null) return null;
    return _updateService.getDownloadUrl(state.latestRelease!);
  }

  /// Get available platforms
  List<String> getAvailablePlatforms() {
    if (state.latestRelease == null) return [];
    return _updateService.getAvailablePlatforms(state.latestRelease!);
  }
}

/// Provider for AppUpdateService
final Provider<AppUpdateService> appUpdateServiceProvider =
    Provider.autoDispose<AppUpdateService>((ref) => AppUpdateService());

final NotifierProvider<AppUpdateNotifier, AppUpdateState> appUpdateProvider =
    NotifierProvider.autoDispose<AppUpdateNotifier, AppUpdateState>(
  AppUpdateNotifier.new,
);

/// Stream provider that automatically checks for updates on app start
///
/// Usage:
/// ```dart
/// final updateState = ref.watch(autoUpdateCheckProvider);
/// if (updateState.hasUpdate) {
///   ShowUpdateDialog(release: updateState.latestRelease);
/// }
/// ```
final FutureProvider<AppUpdateState> autoUpdateCheckProvider =
    FutureProvider.autoDispose<AppUpdateState>((ref) async {
  final service = ref.watch(appUpdateServiceProvider);
  final currentVersion = await AppUpdateService.getCurrentVersion();

  // Perform initial check
  final release = await service.checkForUpdates(
    
  );

  final asset =
      release != null ? service.getAssetForCurrentPlatform(release) : null;

  return AppUpdateState(
    latestRelease: release,
    hasUpdate: release != null,
    currentVersion: currentVersion,
    platformAsset: asset,
  );
});

/// Provider for manual update checking with loading state
///
/// Usage:
/// ```dart
/// ref.read(manualUpdateCheckProvider.notifier).check();
/// final state = ref.watch(manualUpdateCheckProvider);
/// if (state.hasUpdate) { ... }
/// ```
class ManualUpdateCheckNotifier extends Notifier<AppUpdateState> {
  AppUpdateService get _updateService => ref.read(appUpdateServiceProvider);

  @override
  AppUpdateState build() {
    // package_info_plus has no sync API; the real version arrives via
    // _loadActualVersion() shortly after build.
    _loadActualVersion();
    return const AppUpdateState();
  }

  Future<void> _loadActualVersion() async {
    final actualVersion = await AppUpdateService.getCurrentVersion();
    if (!ref.mounted) return;
    state = state.copyWith(currentVersion: actualVersion);
  }

  Future<void> check() async {
    state = state.copyWith(isLoading: true);

    try {
      // Clear skipped version for manual check
      await _updateService.clearSkippedVersion();

      final release = await _updateService.checkForUpdates(
        forceRefresh: true, // Always force refresh on manual check
      );
      if (!ref.mounted) return;

      if (release != null) {
        final asset = _updateService.getAssetForCurrentPlatform(release);
        state = state.copyWith(
          isLoading: false,
          latestRelease: release,
          hasUpdate: true,
          platformAsset: asset,
          clearPlatformAsset: asset == null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          hasUpdate: false,
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: mapErrorMessage(e),
      );
    }
  }

  Future<void> skipVersion() async {
    if (state.latestRelease != null) {
      await _updateService.skipVersion(state.latestRelease!.version);
      if (!ref.mounted) return;
      state = state.copyWith(
        hasUpdate: false,
      );
    }
  }
}

final NotifierProvider<ManualUpdateCheckNotifier, AppUpdateState>
manualUpdateCheckProvider =
    NotifierProvider.autoDispose<ManualUpdateCheckNotifier, AppUpdateState>(
  ManualUpdateCheckNotifier.new,
);
