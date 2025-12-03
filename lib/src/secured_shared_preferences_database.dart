import 'dart:convert';
import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:ds_easy_db_secure_storage/ds_easy_db_secure_storage.dart';
import 'package:encrypt/encrypt.dart';

/// AES-encrypted SharedPreferences implementation of [DatabaseRepository].
///
/// Combines SharedPreferences for storage with AES-256 encryption for security.
/// The encryption key is stored securely using FlutterSecureStorage.
///
/// Features:
/// - AES-256-GCM encryption
/// - Secure key storage via FlutterSecureStorage
/// - Transparent encryption/decryption
/// - Cross-platform support
/// - Perfect balance between performance and security
///
/// Example:
/// ```dart
/// db.configure(
///   prefs: SecuredSharedPreferencesDatabase(),
///   // ...
/// );
/// ```
class SecuredSharedPreferencesDatabase implements DatabaseRepository {
  final SharedPreferencesDatabase _storage;
  final SecureStorageDatabase _keyStorage;

  late Encrypter _encrypter;
  late IV _iv;

  static const String _encryptionKeyId = '__ds_easy_db_encryption_key__';
  static const String _encryptionIvId = '__ds_easy_db_encryption_iv__';

  /// Creates a new secured SharedPreferences database instance.
  ///
  /// Internally uses SharedPreferences for storage and SecureStorage for
  /// managing the encryption key.
  SecuredSharedPreferencesDatabase()
      : _storage = SharedPreferencesDatabase(),
        _keyStorage = SecureStorageDatabase();

  @override
  Future<void> init() async {
    await _storage.init();
    await _keyStorage.init();

    // Load or generate encryption key
    var keyData = await _keyStorage.get('system', _encryptionKeyId);
    if (keyData == null) {
      // Generate new key
      final key = Key.fromSecureRandom(32);
      final iv = IV.fromSecureRandom(16);

      await _keyStorage.set('system', _encryptionKeyId, {
        'key': base64.encode(key.bytes),
      });
      await _keyStorage.set('system', _encryptionIvId, {
        'iv': base64.encode(iv.bytes),
      });

      _encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      _iv = iv;
    } else {
      // Load existing key
      final ivData = await _keyStorage.get('system', _encryptionIvId);
      final key = Key(base64.decode(keyData['key']));
      _iv = IV(base64.decode(ivData!['iv']));
      _encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    }
  }

  String _encrypt(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  String _decrypt(String encryptedText) {
    final encrypted = Encrypted.fromBase64(encryptedText);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }

  @override
  Future<void> set(
      String collection, String id, Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data);
    final encrypted = _encrypt(jsonString);

    await _storage.set(collection, id, {'__encrypted__': encrypted});
  }

  @override
  Future<void> update(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    // Get existing data
    final existing = await get(collection, id) ?? {};
    final updated = {...existing, ...data};

    // Encrypt and save
    await set(collection, id, updated);
  }

  @override
  Future<Map<String, dynamic>?> get(
    String collection,
    String id, {
    dynamic defaultValue,
  }) async {
    final encryptedData = await _storage.get(collection, id);

    if (encryptedData == null) return defaultValue;

    try {
      final encrypted = encryptedData['__encrypted__'] as String;
      final decrypted = _decrypt(encrypted);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      return defaultValue;
    }
  }

  @override
  Future<Map<String, dynamic>?> getAll(String collection) async {
    final allEncrypted = await _storage.getAll(collection);

    if (allEncrypted == null) return null;

    final Map<String, dynamic> result = {};

    for (var entry in allEncrypted.entries) {
      try {
        final encrypted = entry.value['__encrypted__'] as String;
        final decrypted = _decrypt(encrypted);
        result[entry.key] = jsonDecode(decrypted);
      } catch (e) {
        // Skip corrupted entries
        continue;
      }
    }

    return result.isEmpty ? null : result;
  }

  @override
  Future<bool> exists(String collection, String id) async {
    return await _storage.exists(collection, id);
  }

  @override
  Future<bool> existsWhere(
    String collection, {
    required Map<String, dynamic> where,
  }) async {
    final items = await query(collection, where: where);
    return items.isNotEmpty;
  }

  @override
  Future<void> delete(String collection, String id) async {
    await _storage.delete(collection, id);
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String collection, {
    Map<String, dynamic> where = const {},
  }) async {
    final all = await getAll(collection);

    if (all == null) return [];

    final items = all.values.cast<Map<String, dynamic>>().toList();

    if (where.isEmpty) return items;

    return items.where((item) {
      for (var entry in where.entries) {
        if (item[entry.key] != entry.value) return false;
      }
      return true;
    }).toList();
  }
}
