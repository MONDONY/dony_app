import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expose la clé Hive du flag onboarding pays', () {
    expect(HiveService.kCountryOnboardingSeen, 'country_onboarding_seen');
  });
}
