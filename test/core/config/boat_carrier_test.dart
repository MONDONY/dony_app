import 'package:dony/core/config/boat_carrier.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({bool gpPro = false, bool isProAccount = false}) => UserModel(
  id: 'u1',
  roles: const ['TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  gpPro: gpPro,
  isProAccount: isProAccount,
);

void main() {
  group('canPublishBoat', () {
    test('canPublishBoat_gpPro : badge GP Pro accordé', () {
      expect(canPublishBoat(_user(gpPro: true)), isTrue);
    });

    test('compte professionnel', () {
      expect(canPublishBoat(_user(isProAccount: true)), isTrue);
    });

    test('canPublishBoat_kycOnly_false : KYC vérifié sans badge', () {
      expect(canPublishBoat(_user()), isFalse);
    });
  });
}
