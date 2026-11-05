import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classe/app_updater.dart';
import 'package:classe/services/apk_installer.dart';
import 'package:classe/services/release_update_service.dart';
import 'package:classe/update_gate.dart';

class _FakeUpdater implements AppUpdater {
  _FakeUpdater({
    this.info = const AppUpdateInfo(),
    this.downloadSucceeds = true,
  });

  final AppUpdateInfo info;
  final bool downloadSucceeds;
  int downloadCount = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<AppUpdateInfo> check() async => info;

  @override
  Future<bool> downloadUpdate() async {
    downloadCount++;
    return downloadSucceeds;
  }
}

class _NoReleaseService implements ReleaseUpdateService {
  @override
  bool get isSupported => false;

  @override
  Future<ReleaseInfo?> checkForNewRelease() async => null;

  @override
  Future<File?> downloadApk(
    ReleaseInfo release, {
    void Function(int received, int? total)? onProgress,
  }) async => null;
}

class _FakeApkInstaller implements ApkInstaller {
  @override
  bool get isSupported => true;

  @override
  Future<bool> canInstallPackages() async => true;

  @override
  Future<void> openInstallPermissionSettings() async {}

  @override
  Future<bool> installApk(String path) async => true;
}

Widget _app(AppUpdater updater) {
  return MaterialApp(
    home: UpdateGate(
      updater: updater,
      releaseService: _NoReleaseService(),
      apkInstaller: _FakeApkInstaller(),
      child: const Scaffold(body: Center(child: Text('App content'))),
    ),
  );
}

void main() {
  testWidgets('shows no dialog when the app is up to date', (tester) async {
    await tester.pumpWidget(_app(_FakeUpdater()));
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsNothing);
    expect(find.text('Restart required'), findsNothing);
    expect(find.text('New release detected'), findsNothing);
    expect(find.text('App content'), findsOneWidget);
  });

  testWidgets('blocks the app with an update-required dialog', (tester) async {
    await tester.pumpWidget(
      _app(_FakeUpdater(info: const AppUpdateInfo(updateAvailable: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);

    // Tapping outside the dialog must not dismiss it.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
  });

  testWidgets('shows the restart dialog after downloading', (tester) async {
    final updater = _FakeUpdater(
      info: const AppUpdateInfo(updateAvailable: true),
    );
    await tester.pumpWidget(_app(updater));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(updater.downloadCount, 1);
    expect(find.text('Update required'), findsNothing);
    expect(find.text('Restart required'), findsOneWidget);
    expect(find.text('Restart now'), findsOneWidget);
  });

  testWidgets('keeps blocking when the download fails', (tester) async {
    final updater = _FakeUpdater(
      info: const AppUpdateInfo(updateAvailable: true),
      downloadSucceeds: false,
    );
    await tester.pumpWidget(_app(updater));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(updater.downloadCount, 1);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.textContaining('could not be downloaded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows the restart dialog when a patch is already waiting', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeUpdater(info: const AppUpdateInfo(restartRequired: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restart required'), findsOneWidget);
    expect(find.text('Restart now'), findsOneWidget);
  });
}
