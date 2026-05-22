import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _githubOwner = 'silvansan';
const _githubRepo = 'ablaut-App';
const _latestReleaseApiUrl =
    'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest';
const _latestApkDownloadUrl =
    'https://github.com/$_githubOwner/$_githubRepo/releases/latest/download/app-release.apk';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;

  bool get updateAvailable =>
      compareAppVersions(currentVersion, latestVersion) < 0;
}

class AppUpdateService {
  const AppUpdateService({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<AppUpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    if (currentVersion.isEmpty) {
      return null;
    }

    final client = _httpClient ?? http.Client();
    final ownsClient = _httpClient == null;

    try {
      final response = await client.get(
        Uri.parse(_latestReleaseApiUrl),
        headers: const {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) {
        return null;
      }

      final tagName = json['tag_name']?.toString().trim() ?? '';
      final latestVersion = normalizeReleaseVersion(tagName);
      if (latestVersion.isEmpty) {
        return null;
      }

      final htmlUrl = json['html_url']?.toString().trim();
      final downloadUrl = _resolveApkDownloadUrl(json) ??
          htmlUrl ??
          _latestApkDownloadUrl;

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: json['body']?.toString().trim(),
      );
    } catch (_) {
      return null;
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}

String normalizeReleaseVersion(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}

int compareAppVersions(String left, String right) {
  final leftParts = _parseVersionParts(left);
  final rightParts = _parseVersionParts(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < length; index += 1) {
    final leftValue = index < leftParts.length ? leftParts[index] : 0;
    final rightValue = index < rightParts.length ? rightParts[index] : 0;
    if (leftValue != rightValue) {
      return leftValue.compareTo(rightValue);
    }
  }

  return 0;
}

List<int> _parseVersionParts(String value) {
  final normalized = normalizeReleaseVersion(value);
  final core = normalized.split('+').first.split('-').first;
  return core
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
}

String? _resolveApkDownloadUrl(Map<String, dynamic> releaseJson) {
  final assets = releaseJson['assets'];
  if (assets is! List) {
    return null;
  }

  for (final asset in assets) {
    if (asset is! Map<String, dynamic>) {
      continue;
    }

    final name = asset['name']?.toString() ?? '';
    if (name == 'app-release.apk') {
      final browserUrl = asset['browser_download_url']?.toString().trim();
      if (browserUrl != null && browserUrl.isNotEmpty) {
        return browserUrl;
      }
    }
  }

  return null;
}
