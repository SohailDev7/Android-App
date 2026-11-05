import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class ApkInstaller {
  bool get isSupported;
  Future<bool> canInstallPackages();
  Future<void> openInstallPermissionSettings();
  Future<bool> installApk(String path);
}

class AndroidApkInstaller implements ApkInstaller {
  static const _channel = MethodChannel('classe/restart');

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> canInstallPackages() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } catch (e) {
      debugPrint('canInstallPackages failed: $e');
      return false;
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('openInstallPermissionSettings failed: $e');
    }
  }

  @override
  Future<bool> installApk(String path) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('installApk', {'path': path}) ?? false;
    } catch (e) {
      debugPrint('installApk failed: $e');
      return false;
    }
  }
}
