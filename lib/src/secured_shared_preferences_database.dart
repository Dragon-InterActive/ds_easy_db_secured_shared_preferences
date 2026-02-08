import 'dart:convert';
import 'dart:typed_data';
import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:ds_easy_db_secure_storage/ds_easy_db_secure_storage.dart';
import 'package:cryptography/cryptography.dart';

/// AES-encrypted SharedPreferences implementation of [DatabaseRepository].
///
/// Combines SharedPreferences for storage with AES-256 encryption for security.
/// The encryption key is stored securely using FlutterSecureStorage.
///
/// Features:
/// - AES-256-GCM encryption
/// - Secure key storage via FlutterSecureStorage
/// - Transparent encryption/decryption
/// - Cross-platform support (including WASM)
/// - Web Crypto API for better performance in browsers
/// - Perfect balance between performance and security
///
/// Example:
/// ```dart
/// db.configure(
///   prefs: SharedPreferencesDatabase(),
///   secure: SecuredSharedPreferencesDatabase(),
///   // ...
/// );
/// ```
class SecuredSharedPreferencesDatabase implements DatabaseRepository {
  final SharedPreferencesDatabase _storage;
  final SecureStorageDatabase _keyStorage;

  late SecretKey _secretKey;
  late AesGcm _cipher;

  static const String _encryptionKeyId = '__ds_easy_db_encryption_key__';

  /// Creates a new secured SharedPreferences database instance.
  ///
  /// Internally uses SharedPreferences for storage and SecureStorage for
  /// managing the encryption key.
  SecuredSharedPreferencesDatabase()
      : _storage = SharedPreferencesDatabase(),
        _keyStorage = SecureStorageDatabase() {
    _cipher = AesGcm.with256bits();
  }

  @override
  Future<void> init() async {
    await _storage.init();
    await _keyStorage.init();

    // Load or generate encryption key
    var keyData = await _keyStorage.get('system', _encryptionKeyId);
    if (keyData == null) {
      // Generate new key
      _secretKey = await _cipher.newSecretKey();
      final keyBytes = await _secretKey.extractBytes();

      await _keyStorage.set('system', _encryptionKeyId, {
        'key': base64.encode(keyBytes),
      });
    } else {
      // Load existing key
      final keyBytes = base64.decode(keyData['key']);
      _secretKey = SecretKey(keyBytes);
    }
  }

  Future<String> _encrypt(String plainText) async {
    final plainBytes = utf8.encode(plainText);

    final secretBox = await _cipher.encrypt(plainBytes, secretKey: _secretKey);

    // Combine nonce + ciphertext + mac into single base64 string
    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);

    return base64.encode(combined);
  }

  Future<String> _decrypt(String encryptedText) async {
    final combined = base64.decode(encryptedText);

    // Extract nonce(12 bytes), ciphertext(remaining - 16), mac(last 16 bytes)
    final nonce = combined.sublist(0, 12);
    final mac = Mac(combined.sublist(combined.length - 16));
    final cipherText = combined.sublist(12, combined.length - 16);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);

    final decryptedBytes =
        await _cipher.decrypt(secretBox, secretKey: _secretKey);

    return utf8.decode(decryptedBytes);
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
      final decrypted = await _decrypt(encrypted);
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
        final decrypted = await _decrypt(encrypted);
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
