import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento cifrado (Keychain en iOS, Keystore en Android) para tokens.
abstract class SecureStorage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class SecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage storage;

  SecureStorageImpl([this.storage = const FlutterSecureStorage()]);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}
