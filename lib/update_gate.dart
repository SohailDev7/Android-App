import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_updater.dart';
import 'services/apk_installer.dart';
import 'services/release_update_service.dart';
import 'theme/app_theme.dart';

/// Runs mandatory update flows around [child].
///
/// Priority:
/// 1. Full APK release detected (GitHub Releases) -> in-app download + install.
/// 2. Shorebird patch available -> download patch + restart.
/// 3. Shorebird patch already downloaded -> restart.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.updater,
    this.releaseService,
    this.apkInstaller,
  });

  final Widget child;

  /// Optional override, mainly useful for tests.
  final AppUpdater? updater;
  final ReleaseUpdateService? releaseService;
  final ApkInstaller? apkInstaller;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late final AppUpdater _updater = widget.updater ?? ShorebirdAppUpdater();
  late final ReleaseUpdateService _releaseService =
      widget.releaseService ?? GithubReleaseUpdateService();
  late final ApkInstaller _apkInstaller =
      widget.apkInstaller ?? AndroidApkInstaller();
  bool _flowStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runUpdateFlow());
  }

  Future<void> _runUpdateFlow() async {
    if (_flowStarted) return;
    _flowStarted = true;

    // 1) Check for a full APK release (new installed build required).
    if (_releaseService.isSupported) {
      final release = await _releaseService.checkForNewRelease();
      if (!mounted) return;
      if (release != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: _ReleaseRequiredDialog(
              release: release,
              service: _releaseService,
              installer: _apkInstaller,
            ),
          ),
        );
        // If install was launched, Android takes over; keep gate up.
        if (!mounted) return;
        return;
      }
    }

    // 2) Shorebird patch flow (Dart-only OTA).
    if (!_updater.isAvailable) return;
    final info = await _updater.check();
    if (!mounted) return;

    if (info.updateAvailable) {
      final downloaded = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: _UpdateRequiredDialog(updater: _updater),
        ),
      );
      if (!mounted) return;
      if (downloaded == true) {
        await _showRestartDialog();
      }
    } else if (info.restartRequired) {
      await _showRestartDialog();
    }
  }

  Future<void> _showRestartDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const PopScope(canPop: false, child: _RestartRequiredDialog()),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReleaseRequiredDialog extends StatefulWidget {
  const _ReleaseRequiredDialog({
    required this.release,
    required this.service,
    required this.installer,
  });

  final ReleaseInfo release;
  final ReleaseUpdateService service;
  final ApkInstaller installer;

  @override
  State<_ReleaseRequiredDialog> createState() => _ReleaseRequiredDialogState();
}

class _ReleaseRequiredDialogState extends State<_ReleaseRequiredDialog> {
  bool _isWorking = false;
  double? _progress;
  String? _downloadedPath;
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isWorking = true;
      _progress = 0;
      _error = null;
    });

    final file = _downloadedPath == null
        ? await widget.service.downloadApk(
            widget.release,
            onProgress: (received, total) {
              if (!mounted) return;
              setState(() {
                _progress = total != null && total > 0 ? received / total : null;
              });
            },
          )
        : null;

    if (!mounted) return;
    final path = file?.path ?? _downloadedPath;
    if (path == null) {
      setState(() {
        _isWorking = false;
        _progress = null;
        _error = 'The update could not be downloaded. Check your connection and try again.';
      });
      return;
    }

    _downloadedPath = path;
    await _install(path);
  }

  Future<void> _install(String path) async {
    setState(() {
      _isWorking = true;
      _error = null;
      _progress = null;
    });

    final canInstall = await widget.installer.canInstallPackages();
    if (!mounted) return;
    if (!canInstall) {
      await widget.installer.openInstallPermissionSettings();
      if (!mounted) return;
      setState(() {
        _isWorking = false;
        _error =
            'Allow installs from this app, then tap "Install update" to continue.';
      });
      return;
    }

    final ok = await widget.installer.installApk(path);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _isWorking = false;
        _error = 'Could not start the installer. You can try again.';
      });
      return;
    }

    // Installer activity opened; keep dialog as a fallback if user returns.
    setState(() {
      _isWorking = false;
      _error = 'Installer opened. Complete installation to use the new version.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDownload = _downloadedPath != null;
    return AlertDialog(
      icon: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          color: AppColors.lime,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.new_releases_rounded,
          size: 32,
          color: AppColors.ink,
        ),
      ),
      title: const Text('New release detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Version ${widget.release.versionName} is available. '
            'Download and install it inside the app to continue.',
            textAlign: TextAlign.center,
          ),
          if (_isWorking) ...[
            const SizedBox(height: 20),
            if (_progress != null)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFFE8E8E3),
                color: AppColors.ink,
              )
            else
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(height: 10),
            Text(
              _progress != null
                  ? 'Downloading update… ${(_progress! * 100).toStringAsFixed(0)}%'
                  : (hasDownload ? 'Starting installer…' : 'Downloading update…'),
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: _isWorking ? null : _downloadAndInstall,
          child: Text(
            hasDownload
                ? (_error != null ? 'Install update' : 'Install again')
                : (_error == null ? 'Download & install' : 'Try again'),
          ),
        ),
      ],
    );
  }
}

/// Non-dismissible dialog that forces the user to download the update.
class _UpdateRequiredDialog extends StatefulWidget {
  const _UpdateRequiredDialog({required this.updater});

  final AppUpdater updater;

  @override
  State<_UpdateRequiredDialog> createState() => _UpdateRequiredDialogState();
}

class _UpdateRequiredDialogState extends State<_UpdateRequiredDialog> {
  bool _isDownloading = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _isDownloading = true;
      _error = null;
    });

    final success = await widget.updater.downloadUpdate();
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isDownloading = false;
      _error = 'The update could not be downloaded. Check your connection and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          color: AppColors.lime,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.system_update_rounded,
          size: 32,
          color: AppColors.ink,
        ),
      ),
      title: const Text('Update required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'A new version of Classe is required to continue. '
            'Update now to keep using the app.',
            textAlign: TextAlign.center,
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 10),
            const Text('Downloading update…', style: TextStyle(fontSize: 13)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: _isDownloading ? null : _download,
          child: Text(_error == null ? 'Update now' : 'Try again'),
        ),
      ],
    );
  }
}

/// Non-dismissible dialog shown once the patch has been downloaded.
class _RestartRequiredDialog extends StatefulWidget {
  const _RestartRequiredDialog();

  @override
  State<_RestartRequiredDialog> createState() => _RestartRequiredDialogState();
}

class _RestartRequiredDialogState extends State<_RestartRequiredDialog> {
  static const _restartChannel = MethodChannel('classe/restart');

  bool _isRestarting = false;
  String? _error;

  Future<void> _restart() async {
    setState(() {
      _isRestarting = true;
      _error = null;
    });

    // Android implements "classe/restart" natively: it relaunches the launch
    // activity and kills the current process, so the downloaded patch is
    // loaded on the next cold start.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _restartChannel.invokeMethod<void>('restart');
        return;
      } on PlatformException catch (error) {
        debugPrint('Restart failed: $error');
      } on MissingPluginException catch (error) {
        debugPrint('Restart channel unavailable: $error');
      }
    }

    if (!mounted) return;
    setState(() {
      _isRestarting = false;
      _error = 'Could not restart automatically. Please close the app and open it again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 70,
        height: 70,
        decoration: const BoxDecoration(
          color: AppColors.lime,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.restart_alt_rounded,
          size: 34,
          color: AppColors.ink,
        ),
      ),
      title: const Text('Restart required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The update has been downloaded. Restart the app to apply it.',
            textAlign: TextAlign.center,
          ),
          if (_isRestarting) ...[
            const SizedBox(height: 20),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 10),
            const Text('Restarting…', style: TextStyle(fontSize: 13)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: _isRestarting ? null : _restart,
          child: const Text('Restart now'),
        ),
      ],
    );
  }
}
