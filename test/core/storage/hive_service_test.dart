import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expose la clé Hive du flag onboarding devise', () {
    expect(HiveService.kCurrencyOnboardingSeen, 'currency_onboarding_seen');
  });
}
