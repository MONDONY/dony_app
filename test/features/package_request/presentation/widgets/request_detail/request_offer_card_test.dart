import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_offer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

NegotiationThread _t(NegotiationThreadStatus s, {bool myTurn = false}) => NegotiationThread(
  id: 't', packageRequestId: 'pr', travelerId: 'tr', travelerTravelDate: DateTime(2026, 9, 26),
  travelerAvailableKg: 8, status: s, currentPriceEur: 25, roundsCount: 1,
  lastActivityAt: DateTime(2026, 9, 17), createdAt: DateTime(2026, 9, 17), messages: const [],
  travelerName: 'Awa K.', travelerRating: 4.9, isMyTurn: myTurn, grossPriceEur: 28, currency: 'EUR',
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('offerTagFor', () {
    expect(offerTagFor(_t(NegotiationThreadStatus.open, myTurn: true), firmPrice: false),
        (label: 'À toi de répondre', tone: OfferTagTone.info, cta: 'Répondre'));
    expect(offerTagFor(_t(NegotiationThreadStatus.open), firmPrice: false).label, 'En attente de Awa K.');
    expect(offerTagFor(_t(NegotiationThreadStatus.open), firmPrice: true),
        (label: 'Disponible pour ton colis', tone: OfferTagTone.success, cta: 'Choisir'));
    expect(offerTagFor(_t(NegotiationThreadStatus.awaitingTrip), firmPrice: false).label, 'Awa K. ajoute son trajet');
    expect(offerTagFor(_t(NegotiationThreadStatus.awaitingPayment), firmPrice: false).tone, OfferTagTone.success);
    expect(offerTagFor(_t(NegotiationThreadStatus.awaitingCommission), firmPrice: false).tone, OfferTagTone.warning);
  });

  testWidgets('affiche nom, note, prix brut et CTA ; tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(body: RequestOfferCard(
      thread: _t(NegotiationThreadStatus.open, myTurn: true), firmPrice: false, onTap: () => taps++))));
    expect(find.text('Awa K.'), findsOneWidget);
    expect(find.text('4,9'), findsOneWidget);
    expect(find.textContaining('28'), findsOneWidget);
    expect(find.text('Répondre'), findsOneWidget);
    await tester.tap(find.byType(RequestOfferCard));
    expect(taps, 1);
  });
}
