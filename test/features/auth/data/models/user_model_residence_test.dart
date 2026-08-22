import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel — adresse de résidence', () {
    test('parse les champs quand ils sont présents', () {
      final u = UserModel.fromJson({
        'id': 'u1',
        'residenceStreet': '12 rue des Lilas',
        'residenceLine2': 'Bat. B',
        'residencePostalCode': '75011',
        'onboardingSeenAt': '2026-08-22T10:00:00Z',
      });

      expect(u.residenceStreet, '12 rue des Lilas');
      expect(u.residenceLine2, 'Bat. B');
      expect(u.residencePostalCode, '75011');
      expect(u.onboardingSeenAt, DateTime.utc(2026, 8, 22, 10));
    });

    test('tolère leur absence — un backend antérieur ne doit rien casser', () {
      final u = UserModel.fromJson({'id': 'u1'});

      expect(u.residenceStreet, isNull);
      expect(u.residenceLine2, isNull);
      expect(u.residencePostalCode, isNull);
      expect(u.onboardingSeenAt, isNull);
    });
  });
}
