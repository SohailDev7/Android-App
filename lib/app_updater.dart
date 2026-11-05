import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// A snapshot of the app's Shorebird update state.
@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    this.currentPatch,
    this.updateAvailable = false,
    this.restartRequired = false,
  });

  /// The currently installed patch number, or null when running the base release.
  final int? currentPatch;

  /// Whether a newer patch can be downloaded.
  final bool updateAvailable;

  /// Whether a downloaded patch is waiting for an app restart.
  final bool restartRequired;
}

/// Abstraction over the update source so the UI can be tested with a fake.
abstract class AppUpdater {
  /// Whether the updater is available in the current build.
  bool get isAvailable;

  /// Checks whether a patch is available or a restart is pending.
  Future<AppUpdateInfo> check();

  /// Downloads the latest patch. Returns true on success.
  Future<bool> downloadUpdate();
}

/// Shorebird-backed [AppUpdater].
///
/// On builds without the Shorebird engine (e.g. `flutter run` in debug) every
/// call is a safe no-op.
class ShorebirdAppUpdater implements AppUpdater {
  ShorebirdUpdater? _updater;

  ShorebirdUpdater get _shorebird => _updater ??= ShorebirdUpdater();

  @override
  bool get isAvailable {
    // Short-circuits in debug/test builds so the Shorebird engine is never
    // touched (and never logs its "updater unavailable" warning).
    return kReleaseMode && _shorebird.isAvailable;
  }

  @override
  Future<AppUpdateInfo> check() async {
    if (!isAvailable) return const AppUpdateInfo();

    try {
      final patch = await _shorebird.readCurrentPatch();
      final status = await _shorebird.checkForUpdate();
      return AppUpdateInfo(
        currentPatch: patch?.number,
        updateAvailable: status == UpdateStatus.outdated,
        restartRequired: status == UpdateStatus.restartRequired,
      );
    } catch (error) {
      debugPrint('Shorebird update check failed: $error');
      return const AppUpdateInfo();
    }
  }

  @override
  Future<bool> downloadUpdate() async {
    if (!isAvailable) return false;

    try {
      await _shorebird.update();
      return true;
    } on UpdateException catch (error) {
      // No downloadable update can also mean the patch was already downloaded
      // (for example by the background updater) and only needs a restart.
      if (error.reason == UpdateFailureReason.noUpdate) return true;
      debugPrint('Shorebird update download failed: $error');
      return false;
    } catch (error) {
      debugPrint('Shorebird update download failed: $error');
      return false;
    }
  }
}
