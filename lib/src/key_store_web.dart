import 'package:web/web.dart' as web;

import 'key_store.dart';

/// Creates the key store for the web.
EncryptionKeyStore createKeyStore() => _SessionStorageKeyStore();

/// Keeps the key in the tab's `sessionStorage`.
///
/// The encrypted data itself lives in `localStorage` (SharedPreferences), the
/// key only in `sessionStorage`. The data therefore survives a reload, but not
/// closing the tab or opening the app in a new one — after that it can no
/// longer be decrypted and is cleaned up on the next start.
///
/// If the browser refuses `sessionStorage` (e.g. strict privacy settings), the
/// key falls back to memory and is lost on reload.
class _SessionStorageKeyStore implements EncryptionKeyStore {
  static const String _name = '__ds_easy_db_encryption_key__';

  String? _memoryFallback;

  @override
  Future<String?> read() async {
    try {
      return web.window.sessionStorage.getItem(_name) ?? _memoryFallback;
    } catch (_) {
      return _memoryFallback;
    }
  }

  @override
  Future<void> write(String key) async {
    _memoryFallback = key;
    try {
      web.window.sessionStorage.setItem(_name, key);
    } catch (_) {
      // Keep the in-memory copy; see the class documentation.
    }
  }
}
