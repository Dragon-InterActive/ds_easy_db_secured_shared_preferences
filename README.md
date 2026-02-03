# DSEasyDB Secured SharedPreferences

AES-encrypted SharedPreferences implementation for [DSEasyDB](https://pub.dev/packages/ds_easy_db). Provides the simplicity of SharedPreferences with the security of AES-256 encryption.

## Features

- **AES-256-GCM Encryption**: Industry-standard encryption for all stored data
- **Automatic Key Management**: Encryption keys are generated and stored securely
- **Transparent Operation**: Encryption/decryption happens automatically
- **Cross-Platform**: Works on iOS, Android, Web, Windows, macOS, Linux
- **Zero Configuration**: Works out of the box
- **Leverages Existing Packages**: Built on top of `ds_easy_db_shared_preferences` and `ds_easy_db_secure_storage`

## When to Use

### ✅ Perfect for Secured SharedPreferences

- Sensitive app settings
- User preferences with PII (Personally Identifiable Information)
- API endpoints and configuration
- Feature flags with sensitive data
- Cached user data
- Session information
- App state with sensitive fields

### ❌ Consider Alternatives

- **Non-sensitive data**: Use `ds_easy_db_shared_preferences` (faster, no encryption overhead)
- **Authentication tokens**: Use `ds_easy_db_secure_storage` (platform-native encryption)
- **Large datasets**: Use encrypted database solutions
- **Binary data**: Use file encryption

## How It Works

1. **First Run**: Generates a random AES-256 key and IV
2. **Key Storage**:
   - **Mobile (iOS/Android)**: Key stored in platform-native secure storage (Keychain/KeyStore) ✅ Secure
   - **Desktop (macOS/Windows/Linux)**: Key stored in OS credential manager ✅ Secure
   - **Web**: Key stored in LocalStorage ⚠️ **NOT truly secure** - just obfuscated
3. **Data Write**: JSON → Encrypt with AES-256-GCM → Store in SharedPreferences
4. **Data Read**: SharedPreferences → Decrypt with AES-256-GCM → JSON

## ⚠️ Web Security Limitation - READ THIS

**On web platforms, this package does NOT provide true security!**

Here's why:

- The encryption key is stored in browser **LocalStorage**
- LocalStorage can be accessed by anyone with browser DevTools
- The encryption only protects against **casual inspection**, not determined attackers
- Anyone with access to the browser can read the key and decrypt your data

**Web is essentially "encrypted LocalStorage" - NOT secure storage!**

### For Production Web Apps

If you need real security on web, consider:

1. **Server-side encryption**: Store sensitive data on your backend
2. **User password**: Derive encryption key from user-provided password/PIN
3. **Session-only data**: Don't persist sensitive data at all
4. **OAuth tokens**: Let the server manage sensitive credentials

**Bottom line**: On web, treat this as "obfuscated storage", not "secure storage".

## Security

- **Algorithm**: AES-256 in GCM mode
- **Key Size**: 256 bits (32 bytes)
- **IV Size**: 128 bits (16 bytes)
- **Key Storage**: Platform-native secure storage (Keychain/KeyStore)
- **Authenticated Encryption**: GCM mode provides both confidentiality and integrity

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  ds_easy_db: ^1.0.2
  ds_easy_db_secured_shared_preferences: ^1.1.1
```

## Usage

### Basic Setup

```dart
import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:ds_easy_db_secured_shared_preferences/ds_easy_db_secured_shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure with both regular and secured SharedPreferences
  db.configure(
    prefs: SharedPreferencesDatabase(),  // Non-sensitive data
    secure: SecuredSharedPreferencesDatabase(),  // Sensitive data
    storage: MockDatabase(),
    stream: MockDatabase(),
  );
  
  await db.init();
  
  runApp(MyApp());
}
```

### Configuration File

In your `easy_db_config.dart`:

```dart
import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:ds_easy_db_secured_shared_preferences/ds_easy_db_secured_shared_preferences.dart';

class EasyDBConfig {
  static DatabaseRepository get prefs => SharedPreferencesDatabase();
  static DatabaseRepository get secure => SecuredSharedPreferencesDatabase();
  // ... other configurations
}
```

## Examples

### Store Non-Sensitive vs Sensitive Data

```dart
// Non-sensitive app settings in prefs (unencrypted, faster)
await db.prefs.set('settings', 'ui', {
  'theme': 'dark',
  'language': 'en',
  'fontSize': 14,
});

// Sensitive user data in secure (encrypted)
await db.secure.set('user', 'profile', {
  'userId': '12345',
  'email': 'user@example.com',
  'phone': '+1234567890',
  'preferences': {
    'notifications': true,
    'newsletter': false,
  },
});

// Read non-sensitive data (fast)
final settings = await db.prefs.get('settings', 'ui');
print('Theme: ${settings?['theme']}');

// Read sensitive data (decrypted automatically)
final profile = await db.secure.get('user', 'profile');
print('Email: ${profile?['email']}');
```

### Store API Configuration with Secrets

```dart
// Non-sensitive API config in prefs
await db.prefs.set('config', 'api_public', {
  'endpoint': 'https://api.example.com/v2',
  'timeout': 30,
  'retryAttempts': 3,
});

// Sensitive API credentials in secure
await db.secure.set('config', 'api_credentials', {
  'clientId': 'your-client-id',
  'clientSecret': 'your-client-secret',
  'apiKey': 'sk-abc123xyz',
});

// Read public config
final publicConfig = await db.prefs.get('config', 'api_public');
print('Endpoint: ${publicConfig?['endpoint']}');

// Read credentials
final credentials = await db.secure.get('config', 'api_credentials');
print('Client ID: ${credentials?['clientId']}');
```

### Store Session Data Securely

```dart
// Store session information in secure (encrypted)
await db.secure.set('session', 'current', {
  'userId': 'user123',
  'sessionId': 'sess_abc123',
  'expiresAt': DateTime.now().add(Duration(days: 7)).toIso8601String(),
  'deviceId': 'device_xyz',
});

// Check session
if (await db.secure.exists('session', 'current')) {
  final session = await db.secure.get('session', 'current');
  print('Active session for: ${session?['userId']}');
}

// Clear session on logout
await db.secure.delete('session', 'current');
```

### Query Encrypted Data

```dart
// Store multiple encrypted items in secure
await db.secure.set('bookmarks', 'bm1', {
  'url': 'https://example.com',
  'title': 'Example Site',
  'private': true,
});

await db.secure.set('bookmarks', 'bm2', {
  'url': 'https://flutter.dev',
  'title': 'Flutter',
  'private': false,
});

// Query works transparently (data is decrypted automatically)
final privateBookmarks = await db.secure.query('bookmarks',
  where: {'private': true}
);
print('Private bookmarks: ${privateBookmarks.length}');
```

### Feature Flags - Separate Public and Sensitive

```dart
// Public feature flags in prefs (unencrypted)
await db.prefs.set('features', 'public', {
  'darkMode': true,
  'newUI': false,
  'apiVersion': 'v2',
});

// Sensitive feature flags in secure (encrypted)
await db.secure.set('features', 'private', {
  'betaFeatures': true,
  'debugMode': false,
  'testUserId': 'test_123', // Sensitive test data
  'internalTools': true,
});

// Read public flags (fast)
final publicFlags = await db.prefs.get('features', 'public');
if (publicFlags?['darkMode'] == true) {
  print('Dark mode enabled');
}

// Read private flags (decrypted)
final privateFlags = await db.secure.get('features', 'private');
if (privateFlags?['betaFeatures'] == true) {
  print('Beta features enabled');
}
```

## Performance Considerations

- **Encryption Overhead**: Minimal performance impact for typical use cases
- **First Read**: Slightly slower due to key loading from SecureStorage
- **Subsequent Operations**: Fast (encryption key cached in memory)
- **Recommendation**: Use for settings and preferences, not high-frequency data

## Comparison with Other Solutions

| Feature | Secured SharedPreferences | SharedPreferences | SecureStorage |
|---------|---------------------------|-------------------|---------------|
| Speed | Medium | Fast | Slow |
| Security | High | None | Very High |
| Data Size | Small-Medium | Small-Medium | Small |
| Use Case | Sensitive settings | Public settings | Tokens/Keys |
| Platform Native | Partial | Yes | Yes |

## Migration from SharedPreferences

```dart
// Old unencrypted data
final oldDb = SharedPreferencesDatabase();
await oldDb.init();

// New encrypted database
final newDb = SecuredSharedPreferencesDatabase();
await newDb.init();

// Migrate data
final oldData = await oldDb.getAll('settings');
if (oldData != null) {
  for (var entry in oldData.entries) {
    await newDb.set('settings', entry.key, entry.value);
  }
  
  // Optionally delete old data
  for (var key in oldData.keys) {
    await oldDb.delete('settings', key);
  }
}
```

## ⚠️ Migration from v1.0.0 to v1.1.1

**Breaking Change**: Version 1.1.1 uses `cryptography` package instead of `encrypt` for WASM compatibility. Data encrypted with v1.0.0 **cannot** be decrypted by v1.1.1.

### Migration Strategies

**Option 1: Fresh Start (Recommended for Development)**

```dart
// Clear old encrypted data and start fresh
await db.secure.delete('collection', 'id');
// Re-enter or re-fetch data
```

**Option 2: Export & Re-encrypt (Production)**

```dart
// BEFORE updating to v1.1.1 (while still on v1.0.0):
final oldData = await db.secure.getAll('user');
// Save oldData to file or send to server temporarily

// AFTER updating to v1.1.1:
await db.secure.init();
for (var entry in oldData.entries) {
  await db.secure.set('user', entry.key, entry.value);
}
```

**Option 3: Parallel Collections**

```dart
// Keep v1.0.0 data readable, new data in v1.1.1 format
await oldDb.secure.get('settings_old', 'key');  // v1.0.0 format
await newDb.secure.get('settings', 'key');      // v1.1.1 format
```

### Why This Breaking Change?

✅ **WASM Compatibility**: Now works with `flutter build web --wasm`
✅ **Better Performance**: Web Crypto API in browsers (up to 500 MB/s)
✅ **Pure Dart**: No native dependencies, better cross-platform support
✅ **Future-Proof**: Actively maintained with modern crypto standards
✅ **Same Security**: Still AES-256-GCM encryption, just different implementation

### When to Update?

- **Development**: Update immediately, data loss is acceptable
- **Production**: Plan migration window, inform users data must be re-synced
- **New Projects**: Always use v1.1.1+

## Security Best Practices

1. **Don't store highly sensitive data**: Use `ds_easy_db_secure_storage` for tokens/passwords
2. **Regular key rotation**: Consider regenerating keys periodically (requires data migration)
3. **Validate data**: Always validate decrypted data before use
4. **Handle errors**: Encryption can fail, implement proper error handling
5. **Clear on logout**: Delete sensitive data when user logs out

## Troubleshooting

### Decryption Errors

```dart
// If decryption fails, data might be corrupted
try {
  final data = await db.prefs.get('collection', 'id');
} catch (e) {
  // Handle decryption error - might need to regenerate key
  print('Decryption failed: $e');
}
```

### Key Lost (Device Reset)

If the encryption key is lost (e.g., after device reset), encrypted data cannot be recovered. Consider implementing:

- Cloud backup of non-sensitive configuration
- Re-authentication flow to fetch fresh data

## Platform-Specific Notes

### iOS/macOS ✅

- Encryption key stored in Keychain (truly secure)
- Survives app reinstall
- Protected by device passcode/biometrics
- **Recommendation**: Safe to use for sensitive data

### Android ✅

- Encryption key stored in KeyStore (truly secure)
- May be lost after "Clear app data"
- Protected by device lock
- **Recommendation**: Safe to use for sensitive data

### Windows/Linux/Desktop ✅

- Key stored in OS credential manager
- Reasonably secure
- **Recommendation**: Safe to use for sensitive data

### Web ⚠️ **NOT SECURE**

- Key stored in **LocalStorage** (browser storage)
- Anyone with browser access can read the key
- DevTools can access LocalStorage easily
- Only protects against casual viewing
- **Recommendation**:
  - DO NOT use for truly sensitive data on web!
  - Consider this "obfuscated storage", not "secure storage"
  - For real security: use server-side encryption or user passwords

## License

BSD-3-Clause License - see LICENSE file for details.

Copyright (c) 2026, MasterNemo (Dragon Software)

---

Feel free to clone and extend. It's free to use and share.
