import 'package:ds_easy_db/ds_easy_db.dart';
import 'package:ds_easy_db_secured_shared_preferences/ds_easy_db_secured_shared_preferences.dart';
import 'package:ds_easy_db_shared_preferences/ds_easy_db_shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SecuredSharedPreferencesDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    db = SecuredSharedPreferencesDatabase();
  });

  test('set and get round-trip (set used to always throw)', () async {
    await db.set('settings', 'theme', {'mode': 'dark'});

    expect(await db.get('settings', 'theme'), {'mode': 'dark'});
  });

  test('works without an explicit init()', () async {
    await db.set('settings', 'theme', {'mode': 'dark'});
    expect(await db.exists('settings', 'theme'), isTrue);
  });

  test('data is not stored in plain text', () async {
    await db.set('settings', 'token', {'value': 'secret-123'});

    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      expect(prefs.get(key).toString(), isNot(contains('secret-123')));
    }
  });

  test('does not collide with SharedPreferencesDatabase on the same names',
      () async {
    final plain = SharedPreferencesDatabase();
    await plain.set('settings', 'theme', {'mode': 'light'});
    await db.set('settings', 'theme', {'mode': 'dark'});

    expect(await plain.get('settings', 'theme'), {'mode': 'light'});
    expect(await db.get('settings', 'theme'), {'mode': 'dark'});
    expect((await plain.getAll('settings'))!.keys, ['theme']);
  });

  test('a second instance reuses the stored key', () async {
    await db.set('settings', 'theme', {'mode': 'dark'});

    final again = SecuredSharedPreferencesDatabase();
    expect(await again.get('settings', 'theme'), {'mode': 'dark'});
  });

  test('concurrent init() calls create only one key', () async {
    await Future.wait([
      db.init(),
      db.init(),
      db.set('a', '1', {'x': 1})
    ]);

    final again = SecuredSharedPreferencesDatabase();
    expect(await again.get('a', '1'), {'x': 1});
  });

  test('a lost key removes the unreadable entries, but nothing else', () async {
    final plain = SharedPreferencesDatabase();
    await plain.set('settings', 'theme', {'mode': 'light'});
    await db.set('settings', 'token', {'value': 'x'});

    // Simulates a wiped key store (new device, cleared keychain, new tab).
    FlutterSecureStorage.setMockInitialValues({});
    final fresh = SecuredSharedPreferencesDatabase();

    expect(await fresh.get('settings', 'token'), isNull);
    expect(await fresh.getAll('settings'), isNull);
    expect(await plain.get('settings', 'theme'), {'mode': 'light'});

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('__ds_secured__:')),
      isEmpty,
    );
  });

  test('DateTime and serverTS are stored as ISO-8601 strings', () async {
    final at = DateTime.utc(2026, 1, 2);
    await db.set('events', 'e1', {
      'at': at,
      'createdAt': DatabaseRepository.serverTS,
    });

    final event = (await db.get('events', 'e1'))!;
    expect(event['at'], at.toIso8601String());
    expect(DateTime.tryParse(event['createdAt'] as String), isNotNull);
  });

  test('update merges', () async {
    await db.set('users', 'u1', {'a': 1});
    await db.update('users', 'u1', {'b': 2});

    expect(await db.get('users', 'u1'), {'a': 1, 'b': 2});
  });

  test('query adds the document id, keeping an own "id" field', () async {
    await db.set('users', 'u1', {'age': 30});
    await db.set('users', 'u2', {'id': 'custom', 'age': 40});

    expect(await db.query('users', where: {'age': 30}), [
      {'id': 'u1', 'age': 30},
    ]);
    expect(
        (await db.query('users', where: {'age': 40})).single['id'], 'custom');
    expect(await db.existsWhere('users', where: {'age': 40}), isTrue);
  });

  test('delete removes the entry', () async {
    await db.set('users', 'u1', {'a': 1});
    await db.delete('users', 'u1');

    expect(await db.exists('users', 'u1'), isFalse);
    expect(await db.getAll('users'), isNull);
  });
}
