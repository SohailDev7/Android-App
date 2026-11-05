import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_updater.dart';
import 'services/apk_installer.dart';
import 'services/release_update_service.dart';
import 'theme/app_theme.dart';

class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.updater,
    this.releaseService,
    this.apkInstaller,
  });

  final Widget child;
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
        if (!mounted) return;
        return;
      }
    }

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
      if (downloaded == true) await _showRestartDialog();
    } else if (info.restartRequired) {
      await _showRestartDialog();
    }
  }

  Future<void> _showRestartDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(canPop: false, child: _RestartRequiredDialog()),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DialogFrame extends StatelessWidget {
  const _DialogFrame({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.actions,
    required this.child,
  });

  final IconData icon;
  final Gradient iconGradient;
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: iconGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.glowShadow,
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).dialogTheme.titleTextStyle),
            const SizedBox(height: 10),
            child,
            const SizedBox(height: 18),
            for (final action in actions) ...[
              SizedBox(width: double.infinity, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: AppColors.primary), const SizedBox(width: 6)],
          Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
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
              setState(() => _progress = total != null && total > 0 ? received / total : null);
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
        _error = 'Allow installs from this app, then tap "Install update" to continue.';
      });
      return;
    }

    final ok = await widget.installer.installApk(path);
    if (!mounted) return;
    setState(() {
      _isWorking = false;
      _error = ok
          ? 'Installer opened. Complete installation to use the new version.'
          : 'Could not start the installer. You can try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDownload = _downloadedPath != null;
    final buttonLabel = hasDownload
        ? (_error != null ? 'Install update' : 'Install again')
        : (_error == null ? 'Download & install' : 'Try again');

    return _DialogFrame(
      icon: Icons.rocket_launch_rounded,
      iconGradient: AppColors.accentGradient,
      title: 'New release detected',
      actions: [
        FilledButton(onPressed: _isWorking ? null : _downloadAndInstall, child: Text(buttonLabel)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusPill(text: 'Version ${widget.release.versionName}', icon: Icons.new_releases_rounded),
          const SizedBox(height: 12),
          Text(
            'A newer build of Classe is ready. Download it here and Android will guide you through installation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).dialogTheme.contentTextStyle,
          ),
          if (_isWorking) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: _progress, minHeight: 8),
            ),
            const SizedBox(height: 10),
            Text(
              _progress != null
                  ? 'Downloading update… ${(_progress! * 100).toStringAsFixed(0)}%'
                  : (hasDownload ? 'Starting installer…' : 'Downloading update…'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _error!.contains('Installer opened') ? const Color(0xFFEFFFFB) : const Color(0xFFFFECEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _error!.contains('Installer opened') ? const Color(0xFFBDEBDD) : const Color(0xFFF6C4C1)),
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: _error!.contains('Installer opened') ? AppColors.success : AppColors.danger,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
    return _DialogFrame(
      icon: Icons.system_update_rounded,
      iconGradient: AppColors.accentGradient,
      title: 'Update required',
      actions: [
        FilledButton(onPressed: _isDownloading ? null : _download, child: Text(_error == null ? 'Update now' : 'Try again')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'A new version of Classe is required to continue. Update now to keep using the app.',
            textAlign: TextAlign.center,
            style: Theme.of(context).dialogTheme.contentTextStyle,
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 10),
            const Text('Downloading update…', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

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
    return _DialogFrame(
      icon: Icons.restart_alt_rounded,
      iconGradient: AppColors.warmGradient,
      title: 'Restart required',
      actions: [
        FilledButton(onPressed: _isRestarting ? null : _restart, child: const Text('Restart now')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'The update has been downloaded. Restart the app to apply it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).dialogTheme.contentTextStyle,
          ),
          if (_isRestarting) ...[
            const SizedBox(height: 16),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 10),
            const Text('Restarting…', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
