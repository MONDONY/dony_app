import 'package:dony/features/settings/data/models/device_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceModel.fromJson', () {
    test('parse un json complet', () {
      final m = DeviceModel.fromJson({
        'deviceId': 'dev-1',
        'deviceName': 'iPhone 14',
        'platform': 'ios',
        'lastSeenAt': '2026-05-22T10:30:00Z',
        'isCurrent': true,
      });
      expect(m.deviceId, 'dev-1');
      expect(m.deviceName, 'iPhone 14');
      expect(m.platform, 'ios');
      expect(m.isCurrent, true);
    });

    test('utilise des fallbacks si champs null/absents', () {
      final m = DeviceModel.fromJson({});
      expect(m.deviceId, '');
      expect(m.deviceName, 'Appareil inconnu');
      expect(m.platform, 'android');
      expect(m.isCurrent, false);
      expect(m.lastSeenAt, isA<DateTime>());
    });

    test('utilise des fallbacks si champs explicitement null', () {
      final m = DeviceModel.fromJson({
        'deviceId': null,
        'deviceName': null,
        'platform': null,
        'lastSeenAt': null,
        'isCurrent': null,
      });
      expect(m.deviceId, '');
      expect(m.deviceName, 'Appareil inconnu');
      expect(m.platform, 'android');
      expect(m.isCurrent, false);
      expect(m.lastSeenAt, isA<DateTime>());
    });

    test('parse une date valide correctement', () {
      final m = DeviceModel.fromJson({
        'deviceId': 'dev-2',
        'deviceName': 'Galaxy S22',
        'platform': 'android',
        'lastSeenAt': '2026-05-21T08:00:00Z',
        'isCurrent': false,
      });
      expect(m.lastSeenAt, DateTime.utc(2026, 5, 21, 8));
      expect(m.isCurrent, false);
    });
  });
}
