import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/traveler_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

AnnouncementModel _announcement({
  required Set<BidPaymentMethod> acceptedPaymentMethods,
}) {
  final now = DateTime(2026, 7, 20);
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: now.add(const Duration(days: 10)),
    availableKg: 20,
    totalKg: 20,
    pricePerKg: 10,
    status: 'PUBLISHED',
    createdAt: now,
    updatedAt: now,
    acceptedPaymentMethods: acceptedPaymentMethods,
  );
}

Widget _wrap(AnnouncementModel a) {
  // consultOnly: true évite le besoin de fournir un FavoriteIdsCubit (utilisé
  // uniquement par l'AppBar en mode non-consultation) — hors du scope de ce test.
  return MaterialApp(
    home: TravelerProfileScreen(announcement: a, consultOnly: true),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  group('TravelerProfileScreen — bannière pas de séquestre (D5, vue expéditeur)', () {
    testWidgets(
        'trajet cash-only — bannière pas de séquestre affichée avec texte exact',
        (tester) async {
      final a = _announcement(
        acceptedPaymentMethods: {BidPaymentMethod.cash},
      );

      await tester.pumpWidget(_wrap(a));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Le paiement se fait en main propre au voyageur, '
          'Yadony ne séquestre pas votre argent et ne peut pas le rembourser '
          'automatiquement en cas de litige.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('trajet avec carte acceptée — pas de bannière',
        (tester) async {
      final a = _announcement(
        acceptedPaymentMethods: {
          BidPaymentMethod.cash,
          BidPaymentMethod.stripe,
        },
      );

      await tester.pumpWidget(_wrap(a));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('ne séquestre pas votre argent'), findsNothing);
    });

    testWidgets('trajet carte uniquement — pas de bannière', (tester) async {
      final a = _announcement(
        acceptedPaymentMethods: {BidPaymentMethod.stripe},
      );

      await tester.pumpWidget(_wrap(a));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('ne séquestre pas votre argent'), findsNothing);
    });
  });
}
