import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Portable backup format. Credentials and tokens must never be supplied here.
class LocalBackupCodec {
  static const _format = 'dniowka-local-backup';
  static const _version = 1;

  static Uint8List encode(Map<String, dynamic> snapshot, {String? password}) {
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));
    if (password == null) {
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': _format,
            'version': _version,
            'encrypted': false,
            'checksum': _sha256(plaintext),
            'payload': snapshot,
          }),
        ),
      );
    }
    if (password.isEmpty) throw ArgumentError.value(password, 'password');
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    final encrypted = cipher.process(plaintext);
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _format,
          'version': _version,
          'encrypted': true,
          'salt': base64Encode(salt),
          'nonce': base64Encode(nonce),
          'payload': base64Encode(encrypted),
        }),
      ),
    );
  }

  static Map<String, dynamic> decode(Uint8List bytes, {String? password}) {
    try {
      final envelope = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      if (envelope['format'] != _format || envelope['version'] != _version) {
        throw const FormatException('Nieobsługiwany format kopii.');
      }
      if (envelope['encrypted'] == true) {
        if (password == null || password.isEmpty) {
          throw const FormatException('Ta kopia wymaga hasła.');
        }
        final salt = base64Decode(envelope['salt'] as String);
        final nonce = base64Decode(envelope['nonce'] as String);
        if (salt.length != 16 || nonce.length != 12) {
          throw const FormatException('Uszkodzona kopia.');
        }
        final cipher = GCMBlockCipher(AESEngine())
          ..init(
            false,
            AEADParameters(
              KeyParameter(_deriveKey(password, salt)),
              128,
              nonce,
              Uint8List(0),
            ),
          );
        final plaintext = cipher.process(base64Decode(envelope['payload'] as String));
        return Map<String, dynamic>.from(jsonDecode(utf8.decode(plaintext)) as Map);
      }
      if (envelope['encrypted'] != false) {
        throw const FormatException('Uszkodzona kopia.');
      }
      final payload = Map<String, dynamic>.from(envelope['payload'] as Map);
      final raw = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      if (_sha256(raw) != envelope['checksum']) {
        throw const FormatException('Suma kontrolna kopii jest niepoprawna.');
      }
      return payload;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Nie można odczytać kopii lub hasło jest błędne.');
    }
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 210000, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  static String _sha256(Uint8List bytes) {
    final digest = SHA256Digest().process(bytes);
    return digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
