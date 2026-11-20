## 1.2.0

* Fixed: `set()` and `update()` always threw (missing `await`), so no data
  could be stored since 1.1.0.
* Fixed (web): the encryption key was kept in memory only, so all data was
  unreadable after a reload. The key now lives in the tab's `sessionStorage`:
  data survives a reload, but not closing the tab.
* Fixed: entries shared their keys with `SharedPreferencesDatabase`, so both
  overwrote each other for equal collection names. Encrypted entries now use
  their own namespace (`__ds_secured__:`).
* Fixed: concurrent `init()` calls could generate two keys.
* Entries that became unreadable because a new key had to be generated are
  removed automatically.
* `exists` only reports readable documents; `query` results include the
  document id as `id`; `DateTime` and `serverTS` are stored as ISO-8601.
* Works without an explicit `init()` call.

## 1.1.1

* Updated to use ds_easy_db_secure_storage

## 1.1.0

* **Breaking** Switched from `encrypt` to `cryptography` package for WASM compatibility
* Added WASM support for Flutter Web
* Uses Web Crypto API in browsers for better performance
* Updated to use ds_easy_db ^1.0.2
* Same security: AES-256-GCM encryption

## 1.0.0

* Initial release
* AES-256-GCM encryption for SharedPreferences
* Automatic key generation and secure storage
* Transparent encryption/decryption
* Combines ds_easy_db_shared_preferences with ds_easy_db_secure_storage
* Cross-platform support
