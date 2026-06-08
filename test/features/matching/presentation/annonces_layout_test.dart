import 'package:dony/features/matching/presentation/annonces_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('annoncesLayoutFor', () {
    test('non-traveler → senderOnly regardless of isPro', () {
      expect(annoncesLayoutFor(isTraveler: false, isPro: false),
          AnnoncesLayout.senderOnly);
      expect(annoncesLayoutFor(isTraveler: false, isPro: true),
          AnnoncesLayout.senderOnly);
    });

    test('traveler non-pro → occasionalTraveler', () {
      expect(annoncesLayoutFor(isTraveler: true, isPro: false),
          AnnoncesLayout.occasionalTraveler);
    });

    test('pro traveler → proTraveler', () {
      expect(annoncesLayoutFor(isTraveler: true, isPro: true),
          AnnoncesLayout.proTraveler);
    });
  });
}
