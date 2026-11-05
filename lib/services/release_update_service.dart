import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

@immutable
class ReleaseInfo {
  const ReleaseInfo({
    required this.versionName,
    required this.tag,
    required this.downloadUrl,
    required this.assetName,
    this.releaseNotes,
    this.htmlUrl,
  });

  final String versionName;
  final String tag;
  final String downloadUrl;
  final String assetName;
  final String? releaseNotes;
  final String? htmlUrl;
}

abstract class ReleaseUpdateService {
  bool get isSupported;
  Future<ReleaseInfo?> checkForNewRelease();
  Future<File?> downloadApk(
    ReleaseInfo release, {
    void Function(int received, int? total)? onProgress,
  });
}

class GithubReleaseUpdateService implements ReleaseUpdateService {
  GithubReleaseUpdateService({
    http.Client? client,
    this.owner = 'SohailDev7',
    this.repo = 'Android-App',
    this.assetNamePattern = '.apk',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String owner;
  final String repo;
  final String assetNamePattern;

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Uri get _latestReleaseUri =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  @override
  Future<ReleaseInfo?> checkForNewRelease() async {
    if (!isSupported) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version.trim();
      final response = await _client.get(
        _latestReleaseUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Classe-App-Updater',
        },
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        debugPrint('Release check failed: HTTP ${response.statusCode}');
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?)?.trim() ?? '';
      final versionName = _normalizeVersion(tag);
      if (versionName.isEmpty || !_isNewer(versionName, current)) return null;

      final assets = (json['assets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e));
      final apk = assets.firstWhere(
        (a) {
          final name = ((a['name'] as String?) ?? '').toLowerCase();
          return name.endsWith(assetNamePattern.toLowerCase());
        },
        orElse: () => const <String, dynamic>{},
      );
      final url = apk['browser_download_url'] as String?;
      final assetName = apk['name'] as String?;
      if (url == null || url.isEmpty || assetName == null || assetName.isEmpty) {
        debugPrint('Latest release has no APK asset: $tag');
        return null;
      }

      return ReleaseInfo(
        versionName: versionName,
        tag: tag,
        downloadUrl: url,
        assetName: assetName,
        releaseNotes: json['body'] as String?,
        htmlUrl: json['html_url'] as String?,
      );
    } catch (e) {
      debugPrint('Release check failed: $e');
      return null;
    }
  }

  @override
  Future<File?> downloadApk(
    ReleaseInfo release, {
    void Function(int received, int? total)? onProgress,
  }) async {
    if (!isSupported) return null;
    IOSink? sink;
    try {
      final dir = await getExternalCacheDirectories();
      final base = (dir != null && dir.isNotEmpty)
          ? dir.first
          : await getTemporaryDirectory();
      final updatesDir = Directory('${base.path}/updates');
      if (!await updatesDir.exists()) {
        await updatesDir.create(recursive: true);
      }
      // Clean old APKs to avoid filling cache.
      await for (final entity in updatesDir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }

      final safeName = release.assetName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${updatesDir.path}/$safeName');
      final request = http.Request('GET', Uri.parse(release.downloadUrl))
        ..headers['User-Agent'] = 'Classe-App-Updater';
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        debugPrint('APK download failed: HTTP ${response.statusCode}');
        return null;
      }
      final total = response.contentLength;
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      return file;
    } catch (e) {
      debugPrint('APK download failed: $e');
      try {
        await sink?.close();
      } catch (_) {}
      return null;
    }
  }

  static String _normalizeVersion(String tag) {
    var v = tag.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    // Allow tags like release-1.2.3
    final match = RegExp(r'(\d+(?:\.\d+){0,3})').firstMatch(v);
    return match?.group(1) ?? v;
  }

  static bool _isNewer(String remote, String current) {
    List<int> parse(String v) => v
        .split(RegExp(r'[.+-]'))
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final r = parse(remote);
    final c = parse(current);
    final len = r.length > c.length ? r.length : c.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }
}
