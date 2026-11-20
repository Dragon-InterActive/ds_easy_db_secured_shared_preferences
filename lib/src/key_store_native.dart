import 'package:ds_easy_db_secure_storage/ds_easy_db_secure_storage.dart';

import 'key_store.dart';

/// Creates the key store for mobile and desktop.
EncryptionKeyStore createKeyStore() => _SecureStorageKeyStore();

/// Keeps the key in Keychain / KeyStore / Credential Manager / libsecret.
///
/// The location (`system:__ds_easy_db_encryption_key__`) is the one earlier
/// versions used, so an existing key keeps working.
class _SecureStorageKeyStore implements EncryptionKeyStore {
  final SecureStorageDatabase _storage = SecureStorageDatabase();

  static const String _collection = 'system';
  static const String _id = '__ds_easy_db_encryption_key__';

  @override
  Future<String?> read() async {
    final stored = await _storage.get(_collection, _id);
    final key = stored?['key'];
    return key is String ? key : null;
  }

  @override
  Future<void> write(String key) async {
    await _storage.set(_collection, _id, {'key': key});
  }
}
