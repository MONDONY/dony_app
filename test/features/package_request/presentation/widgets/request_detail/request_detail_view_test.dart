import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_detail_state.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/package_request_insights.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/compatible_traveler_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_detail_view.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_offer_card.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_progress_timeline.dart';
import 'package:dony/features/package_request/presentation/widgets/request_detail/request_travelers_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

PackageRequest _req(PackageRequestStatus s, {bool negotiable = true}) => PackageRequest(
  id: 'pr-1', senderId: 'sender-1', departureCity: 'Divo', arrivalCity: 'Annemasse',
  desiredDate: DateTime(2026, 9, 27), dateToleranceDays: 2, weightKg: 2,
  parcelSize: ParcelSize.small, transportMode: TransportMode.plane,
  status: s, createdAt: DateTime.utc(2026, 9, 17, 6, 25), negotiable: negotiable,
);

NegotiationThread _t(NegotiationThreadStatus s, {String id = 'a', bool myTurn = false, String? bidId}) => NegotiationThread(
  id: 't-$id', packageRequestId: 'pr-1', travelerId: 'tr-$id', travelerTravelDate: DateTime(2026, 9, 26),
  travelerAvailableKg: 8, status: s, currentPriceEur: 25, roundsCount: 1,
  lastActivityAt: DateTime(2026, 9, 17), createdAt: DateTime(2026, 9, 17), messages: const [],
  travelerName: 'Awa K.', isMyTurn: myTurn, grossPriceEur: 28, currency: 'EUR', materializedBidId: bidId,
);

AnnouncementModel _trip(String id) => AnnouncementModel(
  id: id, travelerId: 'trav-$id', departureCity: 'Divo', arrivalCity: 'Annemasse',
  departureDate: DateTime(2026, 9, 26), availableKg: 8, totalKg: 10, pricePerKg: 7,
  status: 'ACTIVE', createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9),
);

final _noop = RequestDetailCallbacks.noop();

Future<void> _pump(WidgetTester tester, PackageRequestDetailLoaded state, {RequestDetailCallbacks? cb}) =>
    tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(
      body: SingleChildScrollView(child: RequestDetailView(state: state, callbacks: cb ?? _noop)))));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('1 brouillon : bandeau pas visible + aperçu repliée', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.draft), threads: const [],
        compatibleTrips: [_trip('x'), _trip('y')]));
    expect(find.text('Brouillon'), findsOneWidget);
    expect(find.text('Pas encore visible'), findsOneWidget);
    expect(find.text('2 voyageurs la verront'), findsOneWidget);
  });

  testWidgets('2 publiée sans offre : vues + liste + Inviter', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.open), threads: const [],
        insights: const PackageRequestInsights(viewCount: 14, invitedAnnouncementIds: {}),
        invitationsSupported: true, compatibleTrips: [_trip('x')]));
    expect(find.textContaining('14 vues'), findsOneWidget);
    expect(find.byType(RequestTravelersList), findsOneWidget);
    expect(find.text('Inviter'), findsOneWidget);
  });

  testWidgets('2 bis : back sans invitations → pas de bouton Inviter', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.open), threads: const [],
        compatibleTrips: [_trip('x')]));
    expect(find.text('Inviter'), findsNothing);
  });

  testWidgets('3 personne sur l axe : état vide', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.open), threads: const [],
        compatibleTrips: const []));
    expect(find.byType(RequestNoTravelersEmpty), findsOneWidget);
  });

  testWidgets('4 offres reçues : à répondre en tête, voyageurs repliés', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.negotiating),
        threads: [_t(NegotiationThreadStatus.open, id: 'b'), _t(NegotiationThreadStatus.open, id: 'a', myTurn: true)],
        compatibleTrips: [_trip('x')]));
    expect(find.text('2 offres'), findsOneWidget);
    final cards = tester.widgetList<RequestOfferCard>(find.byType(RequestOfferCard)).toList();
    expect(cards.first.thread.isMyTurn, isTrue);
    expect(find.byType(RequestTravelersFold), findsOneWidget);
  });

  testWidgets('5 prix ferme : Choisir + rappel', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.open, negotiable: false),
        threads: [_t(NegotiationThreadStatus.open)]));
    expect(find.text('Choisir'), findsOneWidget);
    expect(find.text('Les autres candidats seront déclinés automatiquement.'), findsOneWidget);
  });

  testWidgets('6 commission espèces : bandeau ambre, autres offres visibles', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.negotiating),
        threads: [_t(NegotiationThreadStatus.open, id: 'b'), _t(NegotiationThreadStatus.awaitingCommission, id: 'a')]));
    expect(find.text('Awa K. règle sa commission Yadony'), findsOneWidget);
    expect(find.byType(RequestOfferCard), findsNWidgets(2));
  });

  testWidgets('7 à finaliser : une seule offre', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.negotiating),
        threads: [_t(NegotiationThreadStatus.open, id: 'b'), _t(NegotiationThreadStatus.awaitingPayment, id: 'a')]));
    expect(find.text('Finalise pour réserver sa place'), findsOneWidget);
    expect(find.byType(RequestOfferCard), findsOneWidget);
  });

  testWidgets('8 acceptée : talon voyageur + frise', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.accepted),
        threads: [_t(NegotiationThreadStatus.accepted, bidId: 'bid-1')],
        materializedBid: BidModel(id: 'bid-1', announcementId: 'x', senderId: 'sender-1', weightKg: 2,
            status: 'HANDED_OVER', createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9))));
    expect(find.text('Confirmée'), findsOneWidget);
    expect(find.byKey(const Key('request-ticket-traveler-stub')), findsOneWidget);
    expect(tester.widget<RequestProgressTimeline>(find.byType(RequestProgressTimeline)).currentStep, 2);
  });

  testWidgets('9 livrée : talon, pas de frise', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.accepted),
        threads: [_t(NegotiationThreadStatus.accepted, bidId: 'bid-1')],
        materializedBid: BidModel(id: 'bid-1', announcementId: 'x', senderId: 'sender-1', weightKg: 2,
            status: 'COMPLETED', createdAt: DateTime(2026, 9), updatedAt: DateTime(2026, 9))));
    expect(find.text('Livrée'), findsOneWidget);
    expect(find.byType(RequestProgressTimeline), findsNothing);
  });

  testWidgets('10 expirée : bandeau', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.expired), threads: const []));
    expect(find.text('Date dépassée sans accord'), findsOneWidget);
  });

  testWidgets('11 annulée : bandeau, aucune liste', (tester) async {
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.open), threads: const [],
        cancelledLocally: true, compatibleTrips: [_trip('x')]));
    expect(find.text('Tu as annulé cette demande'), findsOneWidget);
    expect(find.byType(CompatibleTravelerCard), findsNothing);
  });

  testWidgets('tap sur une offre ouvre le fil', (tester) async {
    String? opened;
    await _pump(tester, PackageRequestDetailLoaded(request: _req(PackageRequestStatus.negotiating),
        threads: [_t(NegotiationThreadStatus.open)]),
        cb: RequestDetailCallbacks.noop().copyWith(onOpenThread: (id) => opened = id));
    await tester.tap(find.byType(RequestOfferCard));
    expect(opened, 't-a');
  });
}
