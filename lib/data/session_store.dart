import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The sign-in token and this install's device ID, in Keychain or Keystore.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'mizani.token';
  static const _deviceKey = 'mizani.device_id';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// Stable for the life of the install, so a new sign-in replaces this
  /// device's old token on the server.
  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceKey);
    if (existing != null) {
      return existing;
    }

    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _deviceKey, value: id);
    return id;
  }
}
