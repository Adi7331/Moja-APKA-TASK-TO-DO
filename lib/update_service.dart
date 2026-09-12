import 'dart:convert';
import 'dart:io';

const _githubReleasePrefix =
    'https://github.com/Adi7331/Moja-APKA-TASK-TO-DO/releases/download/';

enum UpdatePlatform { android, windows, other }

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.androidUrl,
    required this.windowsUrl,
    required this.notes,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as String?;
    final androidUrl = _releaseUrl(json['androidUrl']);
    final windowsUrl = json['windowsUrl'] == null
        ? null
        : _releaseUrl(json['windowsUrl']);
    if (version == null ||
        !_stableVersion.hasMatch(version) ||
        androidUrl == null) {
      throw const FormatException('Nieprawidłowy plik aktualizacji.');
    }
    return ReleaseInfo(
      version: version,
      androidUrl: androidUrl,
      windowsUrl: windowsUrl,
      notes: json['notes'] as String? ?? '',
    );
  }

  final String version;
  final Uri androidUrl;
  final Uri? windowsUrl;
  final String notes;

  bool isNewerThan(String currentVersion) {
    if (!_stableVersion.hasMatch(currentVersion)) return false;
    return _versionParts(version).compareTo(_versionParts(currentVersion)) > 0;
  }

  Uri? downloadUrlFor(UpdatePlatform platform) => switch (platform) {
    UpdatePlatform.android => androidUrl,
    UpdatePlatform.windows => windowsUrl,
    UpdatePlatform.other => null,
  };
}

class UpdateService {
  const UpdateService({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  Future<ReleaseInfo?> check(
    String? manifestUrl, {
    required String currentVersion,
  }) async {
    final uri = Uri.tryParse(manifestUrl?.trim() ?? '');
    if (uri == null || uri.scheme != 'https') return null;
    final client = _clientFactory();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await utf8
          .decodeStream(response)
          .timeout(const Duration(seconds: 8));
      final release = ReleaseInfo.fromJson(
        Map<String, dynamic>.from(jsonDecode(body) as Map),
      );
      return release.isNewerThan(currentVersion) ? release : null;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

final _stableVersion = RegExp(r'^\d+\.\d+\.\d+$');

Uri? _releaseUrl(Object? value) {
  if (value is! String || !value.startsWith(_githubReleasePrefix)) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') {
    return null;
  }
  return uri;
}

class _VersionParts implements Comparable<_VersionParts> {
  const _VersionParts(this.parts);
  final List<int> parts;

  @override
  int compareTo(_VersionParts other) {
    for (var index = 0; index < parts.length; index++) {
      final result = parts[index].compareTo(other.parts[index]);
      if (result != 0) return result;
    }
    return 0;
  }
}

_VersionParts _versionParts(String value) =>
    _VersionParts(value.split('.').map(int.parse).toList());
