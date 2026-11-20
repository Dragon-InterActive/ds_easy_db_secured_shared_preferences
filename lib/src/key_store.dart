/// Where the AES key of `SecuredSharedPreferencesDatabase` lives.
///
/// The key is kept apart from the encrypted data: on mobile and desktop in the
/// platform's secure storage, on the web in the tab's `sessionStorage`.
library;

export 'key_store_native.dart'
    if (dart.library.js_interop) 'key_store_web.dart';

/// Reads and writes the base64-encoded AES key.
abstract interface class EncryptionKeyStore {
  /// The stored key, or `null` if none exists yet.
  Future<String?> read();

  /// Persists [key], replacing any previous one.
  Future<void> write(String key);
}
