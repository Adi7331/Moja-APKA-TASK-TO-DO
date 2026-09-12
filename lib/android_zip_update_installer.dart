import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AndroidZipUpdateInstaller {
  AndroidZipUpdateInstaller({
    Future<File> Function(Uri url)? download,
    Future<void> Function(File zipFile)? installZip,
  }) : _download = download ?? _downloadPackage,
       _installZip = installZip ?? _openAndroidInstaller;

  static const _channel = MethodChannel('dzien_po_dniu/update');

  final Future<File> Function(Uri url) _download;
  final Future<void> Function(File zipFile) _installZip;

  Future<bool> start(Uri url, {bool? isAndroid}) async {
    if (!(isAndroid ?? Platform.isAndroid) ||
        !url.path.toLowerCase().endsWith('.zip')) {
      return false;
    }
    try {
      final zipFile = await _download(url);
      await _installZip(zipFile);
      return true;
    } on Object {
      return false;
    }
  }

  static Future<File> _downloadPackage(Uri url) async {
    final directory = await getApplicationSupportDirectory();
    final updates = Directory(
      '${directory.path}${Platform.pathSeparator}updates',
    );
    await updates.create(recursive: true);
    final file = File('${updates.path}${Platform.pathSeparator}update.zip');
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Nie udało się pobrać aktualizacji.');
      }
      final sink = file.openWrite();
      await response.pipe(sink);
      return file;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _openAndroidInstaller(File zipFile) =>
      _channel.invokeMethod<void>('installZip', {'path': zipFile.path});
}
