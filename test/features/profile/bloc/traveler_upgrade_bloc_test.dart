import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/profile/data/traveler_upgrade_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTravelerUpgradeRepository extends Mock
    implements TravelerUpgradeRepository {}

void main() {
  test('MockTravelerUpgradeRepository can be instantiated', () {
    final repo = MockTravelerUpgradeRepository();
    expect(repo, isNotNull);
  });
}
