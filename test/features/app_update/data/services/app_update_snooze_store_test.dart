import 'package:dony/features/app_update/data/services/app_update_snooze_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('aucun report enregistré : null', () async {
    expect(await PrefsAppUpdateSnoozeStore().lastSnoozedAt(), isNull);
  });

  test('relit l\'horodatage écrit', () async {
    final store = PrefsAppUpdateSnoozeStore();
    final at = DateTime.utc(2026, 11, 9, 8, 30);
    await store.snooze(at);
    expect(await store.lastSnoozedAt(), at);
  });

  test('valeur de mauvais type : null, sans exception', () async {
    SharedPreferences.setMockInitialValues({
      PrefsAppUpdateSnoozeStore.key: 'pas un nombre',
    });
    expect(await PrefsAppUpdateSnoozeStore().lastSnoozedAt(), isNull);
  });
}
