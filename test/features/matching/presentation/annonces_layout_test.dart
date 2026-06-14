import 'package:dony/features/matching/presentation/annonces_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('annoncesLayoutFor', () {
    test('pur expéditeur → senderOnly', () {
      expect(
        annoncesLayoutFor(isTraveler: false, isPro: false),
        AnnoncesLayout.senderOnly,
      );
    });

    test('pur expéditeur (isPro ignoré) → senderOnly', () {
      // isPro ne change rien si isTraveler == false
      expect(
        annoncesLayoutFor(isTraveler: false, isPro: true),
        AnnoncesLayout.senderOnly,
      );
    });

    test('voyageur non-PRO → occasionalTraveler', () {
      expect(
        annoncesLayoutFor(isTraveler: true, isPro: false),
        AnnoncesLayout.occasionalTraveler,
      );
    });

    test('voyageur PRO → proTraveler', () {
      expect(
        annoncesLayoutFor(isTraveler: true, isPro: true),
        AnnoncesLayout.proTraveler,
      );
    });

    test('tous les cas couverts — enum exhaustif (3 valeurs)', () {
      final values = AnnoncesLayout.values;
      expect(values, contains(AnnoncesLayout.senderOnly));
      expect(values, contains(AnnoncesLayout.occasionalTraveler));
      expect(values, contains(AnnoncesLayout.proTraveler));
      expect(values.length, 3);
    });
  });
}
