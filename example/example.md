# DSEasyDB Secured SharedPreferences Example

```dart
import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:ds_easy_db_secured_shared_preferences/ds_easy_db_secured_shared_preferences.dart';

void main() async {
  // Configure with both regular and secured SharedPreferences
  db.configure(
    prefs: SharedPreferencesDatabase(),  // Non-sensitive data
    secure: SecuredSharedPreferencesDatabase(),  // Sensitive data (encrypted)
    storage: MockDatabase(),
    stream: MockDatabase(),
  );
  
  await db.init();
  
  // Store NON-SENSITIVE data in prefs (unencrypted, fast)
  await db.prefs.set('settings', 'ui', {
    'theme': 'dark',
    'language': 'en',
    'fontSize': 14,
    'animations': true,
  });
  
  // Store SENSITIVE data in secure (automatically encrypted)
  await db.secure.set('user', 'profile', {
    'userId': '12345',
    'email': 'john@example.com',
    'phone': '+1234567890',
    'dateOfBirth': '1990-01-01',
    'preferences': {
      'notifications': true,
      'newsletter': false,
    },
  });
  
  // Read non-sensitive data (fast)
  final settings = await db.prefs.get('settings', 'ui');
  print('Theme: ${settings?['theme']}');
  
  // Read sensitive data (automatically decrypted)
  final profile = await db.secure.get('user', 'profile');
  print('User Email: ${profile?['email']}');
  
  // Update sensitive data
  await db.secure.update('user', 'profile', {
    'phone': '+9876543210',
  });
  
  // Store public API config in prefs
  await db.prefs.set('config', 'api_public', {
    'endpoint': 'https://api.example.com',
    'timeout': 30,
  });
  
  // Store API credentials in secure
  await db.secure.set('config', 'api_credentials', {
    'clientId': 'abc123',
    'clientSecret': 'xyz789',
  });
  
  // Query encrypted data
  await db.secure.set('bookmarks', 'bm1', {'url': 'example.com', 'private': true});
  await db.secure.set('bookmarks', 'bm2', {'url': 'flutter.dev', 'private': false});
  
  final privateBookmarks = await db.secure.query('bookmarks',
    where: {'private': true}
  );
  print('Private bookmarks: ${privateBookmarks.length}');
  
  // Clear sensitive data on logout
  await db.secure.delete('user', 'profile');
  await db.secure.delete('config', 'api_credentials');
}
```

## Best Practices Example

```dart
class AppStorage {
  // Non-sensitive: Use prefs (fast, unencrypted)
  static Future<void> saveTheme(String theme) async {
    await db.prefs.set('settings', 'theme', {'mode': theme});
  }
  
  static Future<String?> getTheme() async {
    final data = await db.prefs.get('settings', 'theme');
    return data?['mode'];
  }
  
  // Sensitive: Use secure (encrypted)
  static Future<void> saveUserCredentials(String email, String token) async {
    await db.secure.set('auth', 'credentials', {
      'email': email,
      'token': token,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }
  
  static Future<Map<String, dynamic>?> getUserCredentials() async {
    return await db.secure.get('auth', 'credentials');
  }
  
  static Future<void> clearUserData() async {
    await db.secure.delete('auth', 'credentials');
    await db.secure.delete('user', 'profile');
  }
}
```

## Migration Example

```dart
import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:ds_easy_db_secured_shared_preferences/ds_easy_db_secured_shared_preferences.dart';

Future<void> migrateToEncrypted() async {
  // Old unencrypted storage
  final oldStorage = SharedPreferencesDatabase();
  await oldStorage.init();
  
  // New encrypted storage
  final newStorage = SecuredSharedPreferencesDatabase();
  await newStorage.init();
  
  // Migrate all data
  final collections = ['settings', 'user', 'config'];
  
  for (var collection in collections) {
    final data = await oldStorage.getAll(collection);
    if (data != null) {
      for (var entry in data.entries) {
        await newStorage.set(collection, entry.key, entry.value);
      }
    }
  }
  
  print('Migration complete! Data is now encrypted.');
}
```
