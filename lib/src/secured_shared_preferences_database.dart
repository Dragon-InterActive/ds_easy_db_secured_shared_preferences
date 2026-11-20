import 'dart:convert';
import 'dart:typed_data';
import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'key_store.dart';

/// AES-encrypted SharedPreferences implementation of [DatabaseRepository].
///
/// Combines SharedPreferences for storage with AES-256 encryption for security.
///
/// Features:
/// - AES-256-GCM encryption
/// - Transparent encryption/decryption
/// - Cross-platform support (including WASM)
/// - Web Crypto API for better performance in browsers
///
/// Where the encryption key lives:
/// - **Mobile / desktop**: platform secure storage (Keychain, KeyStore,
///   Credential Manager, libsecret). Data survives app restarts.
/// - **Web**: the tab's `sessionStorage`. Data survives a reload, but not
///   closing the tab — afterwards it cannot be decrypted anymore. On the web
///   key and data are both readable by anyone with access to the browser, so
///   treat this as obfuscation, not as secure storage.
///
/// Whenever a new key has to be generated, entries encrypted with an earlier
/// key are unreadable and are removed.
///
/// Encrypted entries use their own key namespace and never collide with a
/// [SharedPreferencesDatabase] that uses the same collection names.
///
/// `DateTime` values (including [DatabaseRepository.serverTS]) are stored as
/// ISO-8601 strings and come back as strings.
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
  /// Creates a new secured SharedPreferences database instance.
  SecuredSharedPreferencesDatabase()
      : _storage = SharedPreferencesDatabase(),
        _keyStore = createKeyStore();

  final SharedPreferencesDatabase _storage;
  final EncryptionKeyStore _keyStore;
  final AesGcm _cipher = AesGcm.with256bits();

  Future<SecretKey>? _secretKey;

  /// Prefix of every collection this class writes into SharedPreferences.
  static const String _namespace = '__ds_secured__:';

  static const String _payloadField = '__encrypted__';

  /// Loads or generates the encryption key. Called automatically on first use;
  /// concurrent calls share one initialisation.
  @override
  Future<void> init() async {
    await _storage.init();
    await _key();
  }

  Future<SecretKey> _key() async {
    final pending = _secretKey ??= _loadOrCreateKey();
    try {
      return await pending;
    } catch (_) {
      // Do not cache a failure: the next call gets a fresh attempt.
      if (identical(_secretKey, pending)) _secretKey = null;
      rethrow;
    }
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final stored = await _keyStore.read();
    if (stored != null) {
      try {
        final bytes = base64.decode(stored);
        if (bytes.length == 32) return SecretKey(bytes);
      } on FormatException {
        // Fall through and replace the unusable key.
      }
    }

    final key = await _cipher.newSecretKey();
    // Whatever was encrypted before cannot be decrypted with the new key.
    await _removeUnreadableEntries();
    await _keyStore.write(base64.encode(await key.extractBytes()));
    return key;
  }

  Future<void> _removeUnreadableEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final stale = prefs.getKeys().where((key) => key.startsWith(_namespace));
    for (final key in stale.toList()) {
      await prefs.remove(key);
    }
  }

  String _collection(String collection) => '$_namespace$collection';

  Future<String> _encrypt(String plainText) async {
    final secretBox = await _cipher.encrypt(
      utf8.encode(plainText),
      secretKey: await _key(),
    );

    // nonce (12 bytes) + ciphertext + mac (16 bytes), base64-encoded.
    return base64.encode(Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]));
  }

  Future<String> _decrypt(String encryptedText) async {
    final combined = base64.decode(encryptedText);

    final nonce = combined.sublist(0, 12);
    final mac = Mac(combined.sublist(combined.length - 16));
    final cipherText = combined.sublist(12, combined.length - 16);

    final decryptedBytes = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: await _key(),
    );

    return utf8.decode(decryptedBytes);
  }

  Map<String, dynamic> _resolveServerTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value == DatabaseRepository.serverTS) {
        return MapEntry(key, DateTime.now().toIso8601String());
      }
      return MapEntry(key, value);
    });
  }

  String _encode(Map<String, dynamic> data) => jsonEncode(
        data,
        toEncodable: (value) => value is DateTime
            ? value.toIso8601String()
            : throw JsonUnsupportedObjectError(value),
      );

  /// Decrypts one stored entry, or returns `null` if it is not readable.
  Future<Map<String, dynamic>?> _open(Object? stored) async {
    if (stored is! Map) return null;
    final payload = stored[_payloadField];
    if (payload is! String) return null;
    try {
      final decoded = jsonDecode(await _decrypt(payload));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final encrypted = await _encrypt(_encode(data));
    await _storage.set(_collection(collection), id, {_payloadField: encrypted});
  }

  @override
  Future<void> set(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _write(collection, id, _resolveServerTimestamps(data));
  }

  @override
  Future<void> update(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final existing = await get(collection, id) ?? <String, dynamic>{};
    await _write(
      collection,
      id,
      {...existing, ..._resolveServerTimestamps(data)},
    );
  }

  @override
  Future<Map<String, dynamic>?> get(
    String collection,
    String id, {
    dynamic defaultValue,
  }) async {
    final stored = await _storage.get(_collection(collection), id);
    return await _open(stored) ?? defaultValue;
  }

  @override
  Future<Map<String, dynamic>?> getAll(String collection) async {
    final allEncrypted = await _storage.getAll(_collection(collection));
    if (allEncrypted == null) return null;

    final result = <String, dynamic>{};
    for (final entry in allEncrypted.entries) {
      final document = await _open(entry.value);
      if (document != null) result[entry.key] = document;
    }
    return result.isEmpty ? null : result;
  }

  /// Whether a readable document exists under [id].
  @override
  Future<bool> exists(String collection, String id) async {
    return await get(collection, id) != null;
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
    await _storage.delete(_collection(collection), id);
  }

  /// Returns the matching documents, each with its document id under `id`.
  ///
  /// A document that carries its own `id` field keeps it.
  @override
  Future<List<Map<String, dynamic>>> query(
    String collection, {
    Map<String, dynamic> where = const {},
  }) async {
    final all = await getAll(collection);
    if (all == null) return [];

    return [
      for (final entry in all.entries)
        if (_matches(entry.value as Map<String, dynamic>, where))
          <String, dynamic>{'id': entry.key, ...entry.value},
    ];
  }

  bool _matches(Map<String, dynamic> document, Map<String, dynamic> where) {
    for (final entry in where.entries) {
      if (document[entry.key] != entry.value) return false;
    }
    return true;
  }
}
