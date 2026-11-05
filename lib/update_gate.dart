import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_updater.dart';
import 'theme/app_theme.dart';

/// Runs the mandatory update flow around [child].
///
/// If a patch is available the user cannot use the app until it is
/// downloaded, and once downloaded a restart dialog is shown.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child, this.updater});

  final Widget child;

  /// Optional override, mainly useful for tests.
  final AppUpdater? updater;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late final AppUpdater _updater = widget.updater ?? ShorebirdAppUpdater();
  bool _flowStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runUpdateFlow());
  }

  Future<void> _runUpdateFlow() async {
    if (_flowStarted || !_updater.isAvailable) return;
    _flowStarted = true;

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
