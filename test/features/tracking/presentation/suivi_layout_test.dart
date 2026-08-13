import 'package:dony/features/tracking/presentation/suivi_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non voyageur → senderOnly', () {
    expect(
      suiviLayoutFor(isTraveler: false, isPro: false),
      SuiviLayout.senderOnly,
    );
    expect(
      suiviLayoutFor(isTraveler: false, isPro: true),
      SuiviLayout.senderOnly,
    );
  });
  test('voyageur non pro → occasionalTraveler', () {
    expect(
      suiviLayoutFor(isTraveler: true, isPro: false),
      SuiviLayout.occasionalTraveler,
    );
  });
  test('voyageur pro → proTraveler', () {
    expect(
      suiviLayoutFor(isTraveler: true, isPro: true),
      SuiviLayout.proTraveler,
    );
  });
}
