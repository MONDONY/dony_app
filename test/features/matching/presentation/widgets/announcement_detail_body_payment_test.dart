import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/announcement_detail_body.dart';
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
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: AnnouncementDetailBody(a: a),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  group('AnnouncementDetailBody — bannière pas de séquestre (cash-only)', () {
    testWidgets(
        'trajet cash-only — bannière pas de séquestre affichée avec texte exact',
        (tester) async {
      final a = _announcement(
        acceptedPaymentMethods: {BidPaymentMethod.cash},
      );

      await tester.pumpWidget(_wrap(a));
      await tester.pumpAndSettle();

      expect(find.textContaining('ne séquestre pas votre argent'),
          findsOneWidget);
      expect(find.textContaining('Trajet en espèces uniquement.'),
          findsOneWidget);
      expect(
        find.textContaining(
          'Le paiement se fait en main propre au voyageur — '
          'dony ne séquestre pas votre argent et ne peut pas le rembourser '
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
