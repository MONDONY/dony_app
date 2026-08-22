import 'package:dony/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expose la clé Hive du blocage voyageur pays non disponible', () {
    expect(
      HiveService.kTravelerCountryUnsupported,
      'traveler_country_unsupported',
    );
  });
}
