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
