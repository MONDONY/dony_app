import 'package:dony/app/mobile_money_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les liens `yadony://bids/{uuid}/mobile-money/awaiting` et
/// `yadony://negotiations/{uuid}/mobile-money/awaiting` sont ouverts depuis la
/// notification push `MM_PAYMENT_PENDING` ou une reprise externe du paiement
/// mobile money (bid ou fil de négociation). Comme pour
/// `resolveAnnouncementDeepLink`, la liste blanche par égalité stricte de
/// `app.dart` ne peut pas porter un identifiant variable : la validation du
/// segment UUID vit ici, testée isolément.
void main() {
  const uuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

  group('resolveMobileMoneyAwaitingDeepLink', () {
    test('résout un UUID valide vers l\'écran d\'attente du paiement', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://bids/$uuid/mobile-money/awaiting'),
        ),
        '/bids/$uuid/mobile-money/awaiting',
      );
    });

    test('accepte un UUID en majuscules', () {
      final upper = uuid.toUpperCase();
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://bids/$upper/mobile-money/awaiting'),
        ),
        '/bids/$upper/mobile-money/awaiting',
      );
    });

    test('rejette un autre schéma', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('https://bids/$uuid/mobile-money/awaiting'),
        ),
        isNull,
      );
    });

    test('rejette un autre hôte', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://admin/$uuid/mobile-money/awaiting'),
        ),
        isNull,
      );
    });

    test(
      'résout un UUID valide vers l\'écran d\'attente d\'un fil de '
      'négociation',
      () {
        expect(
          resolveMobileMoneyAwaitingDeepLink(
            Uri.parse('yadony://negotiations/$uuid/mobile-money/awaiting'),
          ),
          '/negotiations/$uuid/mobile-money/awaiting',
        );
      },
    );

    test(
      'rejette un identifiant qui n\'est pas un UUID (fil de négociation)',
      () {
        expect(
          resolveMobileMoneyAwaitingDeepLink(
            Uri.parse('yadony://negotiations/42/mobile-money/awaiting'),
          ),
          isNull,
        );
      },
    );

    test('rejette un identifiant qui n\'est pas un UUID', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://bids/42/mobile-money/awaiting'),
        ),
        isNull,
      );
    });

    test('rejette un chemin incomplet (segment manquant)', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(Uri.parse('yadony://bids/$uuid')),
        isNull,
      );
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://bids/$uuid/mobile-money'),
        ),
        isNull,
      );
    });

    test('rejette un segment final différent de "awaiting"', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://bids/$uuid/mobile-money/status'),
        ),
        isNull,
      );
    });

    test('rejette un segment intermédiaire différent de "mobile-money"', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://bids/$uuid/other/awaiting'),
        ),
        isNull,
      );
    });

    test('rejette un chemin vide', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(Uri.parse('yadony://bids')),
        isNull,
      );
    });

    /// Sans validation stricte du segment, une correspondance par préfixe
    /// laisserait ce lien atteindre une route non prévue.
    test('rejette une tentative de remontée de chemin', () {
      expect(
        resolveMobileMoneyAwaitingDeepLink(
          Uri.parse('yadony://bids/../admin/mobile-money/awaiting'),
        ),
        isNull,
      );
    });
  });
}
