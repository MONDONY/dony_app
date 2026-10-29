import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_entry.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_details_content.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tracking_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockAmendmentRepository extends Mock implements BidAmendmentRepository {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

/// Comme bid_detail_screen : le talon « Code de retrait bloqué » (FLUTTER-G1)
/// lit TrackingBloc et BidBloc au build.
TrackingBloc _trackingBloc() {
  final b = _MockTrackingBloc();
  when(() => b.state).thenReturn(TrackingInitial());
  return b;
}

BidBloc _bidBloc() {
  final b = _MockBidBloc();
  when(() => b.state).thenReturn(BidInitial());
  return b;
}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockSupplementRepository extends Mock
    implements BidSupplementRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

// ── Fixture ───────────────────────────────────────────────────────────────────

BidModel _bid({
  String status = 'ACCEPTED',
  String? travelerName = 'Mamadou',
  bool travelerPhoneAvailable = true,
  double? travelerAverageRating = 4.7,
  int? travelerTotalTrips = 8,
  String? recipientName = 'Fatou',
  String? recipientPhone = '+221700000000',
  double? weightKg = 5.0,
  String? contentCategory = 'Vêtements',
  BidPaymentMethod paymentMethod = BidPaymentMethod.stripe,
  double? totalAmountEur = 56.0,
  String? trackingToken = 'tok-abc123',
  String? departureCity = 'Paris',
  String? arrivalCity = 'Dakar',
  bool senderHasRated = false,
  String? arrivalInstructions,
  BidSupplement? supplement,
  List<BidAmendment> amendments = const [],
  bool amendmentAllowed = false,
  TravelerTrackingModel? travelerTracking,
  AddressData? handoverAddress,
  String? recipientAppStatus,
  String? confirmationCode,
  bool pickupCodeRenewalNeeded = false,
  DateTime? departureAt,
  TripRescheduleInfo? reschedule,
}) => BidModel(
  reschedule: reschedule,
  recipientAppStatus: recipientAppStatus,
  confirmationCode: confirmationCode,
  pickupCodeRenewalNeeded: pickupCodeRenewalNeeded,
  departureAt: departureAt,
  travelerTracking: travelerTracking,
  handoverAddress: handoverAddress,
  supplement: supplement,
  amendments: amendments,
  amendmentAllowed: amendmentAllowed,
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: 'sender-001',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  travelerId: 'traveler-001',
  travelerName: travelerName,
  travelerPhoneAvailable: travelerPhoneAvailable,
  travelerAverageRating: travelerAverageRating,
  travelerTotalTrips: travelerTotalTrips,
  recipientName: recipientName,
  recipientPhone: recipientPhone,
  weightKg: weightKg,
  contentCategory: contentCategory,
  paymentMethod: paymentMethod,
  totalAmountEur: totalAmountEur,
  trackingToken: trackingToken,
  departureCity: departureCity,
  arrivalCity: arrivalCity,
  senderHasRated: senderHasRated,
  arrivalInstructions: arrivalInstructions,
);

// ── Host widget ───────────────────────────────────────────────────────────────

Widget _host(
  BidModel bid,
  _MockCancellationBloc cancellationBloc,
  _MockConversationOpenBloc conversationOpenBloc, {
  bool focusSupplement = false,
  bool focusAmendment = false,
  PaymentModel? existingPayment,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<TrackingBloc>.value(value: _trackingBloc()),
          BlocProvider<BidBloc>.value(value: _bidBloc()),
          BlocProvider<CancellationBloc>.value(value: cancellationBloc),
          BlocProvider<ConversationOpenBloc>.value(value: conversationOpenBloc),
        ],
        child: SenderDetailBody(
          bid: bid,
          focusSupplement: focusSupplement,
          focusAmendment: focusAmendment,
          existingPayment: existingPayment,
        ),
      ),
    ),
  );
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  late _MockCancellationBloc cancellationBloc;
  late _MockConversationOpenBloc conversationOpenBloc;

  setUp(() {
    cancellationBloc = _MockCancellationBloc();
    whenListen<CancellationState>(
      cancellationBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );
    conversationOpenBloc = _MockConversationOpenBloc();
    whenListen<ConversationOpenState>(
      conversationOpenBloc,
      const Stream<ConversationOpenState>.empty(),
      initialState: const ConversationOpenInitial(),
    );
  });

  // Large surface so the staggered column doesn't overflow.
  void sizeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // ── Tuile Suivi : le suivi du voyageur n'est plus dans le corps ────────────
  group('Suivi du voyageur dans la liste', () {
    setUp(() {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerFactory<TravelerTrackingCardCubit>(
        () => TravelerTrackingCardCubit(analytics: analytics),
      );
    });
    tearDown(() async => getIt.reset());

    testWidgets('la carte vit dans le sheet de la tuile Suivi, pas au corps', (
      tester,
    ) async {
      sizeView(tester);
      final bid = _bid(
        status: 'IN_TRANSIT',
        travelerTracking: const TravelerTrackingModel(
          status: TravelerTrackingStatus.enRoute,
          nearestCity: 'Lyon',
        ),
        handoverAddress: const AddressData(
          label: '1 rue A',
          lat: 48.8,
          lng: 2.3,
        ),
      );
      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      // Passes de 400 ms : le stagger de flutter_animate laisse des Timers.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(find.byType(TravelerTrackingCard), findsNothing);
      expect(find.byType(ParcelLocationsCard), findsNothing);
      expect(_tile('Suivi'), findsOneWidget);
      expect(_tile('Lieux'), findsNothing);
      // Résumé : « Étape en cours » en pastille.
      expect(
        find.descendant(
          of: _tile('Suivi'),
          matching: find.text('Étape en cours'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sans champ servi par le back et sans adresse : pas de tuile '
        'Suivi', (tester) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(status: 'IN_TRANSIT'),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(TravelerTrackingCard), findsNothing);
      expect(_tile('Suivi'), findsNothing);
    });
  });

  // ── Le paiement lu par l'écran arrive à la carte Paiement ──────────────────
  testWidgets('le paiement transmis arrive à PaiementCard', (tester) async {
    sizeView(tester);
    final bid = _bid(status: 'PENDING');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Paiement échoué'), findsNothing);

    await tester.pumpWidget(
      _host(
        bid,
        cancellationBloc,
        conversationOpenBloc,
        existingPayment: const PaymentModel(
          id: 'pay-1',
          bidId: 'bid-001',
          amount: 56,
          commissionAmount: 5,
          status: PaymentStatus.failed,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final card = tester.widget<PaiementCard>(find.byType(PaiementCard));
    expect(card.existingPayment?.status, PaymentStatus.failed);
    expect(find.text('Paiement échoué'), findsOneWidget);
  });

  // ── Test 1: ACCEPTED → billet, voyageur, paiement, tuiles ───────────────────
  testWidgets('1 · ACCEPTED → ColisBillet, VoyageurContactCard, PaiementCard '
      'puis les tuiles, sans bannière ni cartes retirées', (tester) async {
    sizeView(tester);
    final bid = _bid();

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    // Laisse les staggers (60ms × index + 300ms fadeIn) se terminer.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ColisBillet), findsOneWidget);
    expect(find.byType(VoyageurContactCard), findsOneWidget);
    expect(find.byType(PaiementCard), findsOneWidget);
    expect(find.text('Votre envoi'), findsOneWidget);
    expect(find.text('À traiter'), findsNothing);
    expect(find.byType(SenderHeroCard), findsNothing);
    expect(find.byType(ColisDestinataireCard), findsNothing);
    expect(find.byType(BidDetailsContent), findsNothing);
    expect(find.byType(PrevenirDestinataireBody), findsNothing);
    expect(find.text('Suivi du colis'), findsNothing);
    // ACCEPTED avec lien de suivi : Prévenir, Colis et Plus de détails (pas
    // d'adresse ici, donc pas de tuile Lieux).
    expect(_tile('Prévenir Fatou'), findsOneWidget);
    expect(_tile('Colis et destinataire'), findsOneWidget);
    expect(_tile('Plus de détails'), findsOneWidget);
    expect(find.byType(DonyActionTile), findsNWidgets(3));
  });

  // ── Ordre : billet, À traiter, consignes, voyageur, paiement, tuiles ───────
  testWidgets('l\'ordre est billet, À traiter, consignes, voyageur, paiement, '
      'Votre envoi, tuiles', (tester) async {
    sizeView(tester);
    final bid = _bid(
      status: 'IN_TRANSIT',
      recipientAppStatus: 'DECLINED',
      arrivalInstructions: 'Gare routière, quai 4',
    );

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    double top(Finder f) => tester.getTopLeft(f).dy;
    final ys = [
      top(find.byType(ColisBillet)),
      top(find.text('À traiter')),
      top(_tile('Destinataire à remplacer')),
      top(find.byKey(const Key('arrival-instructions-card'))),
      top(find.byType(VoyageurContactCard)),
      top(find.byType(PaiementCard)),
      top(find.text('Votre envoi')),
      top(_tile('Colis et destinataire')),
    ];
    expect([...ys]..sort(), ys);
    expect(ys.toSet(), hasLength(ys.length));
  });

  // ── « À traiter » ne coiffe que ce qui attend une réponse ──────────────────
  testWidgets('COMPLETED + consignes de retrait → carte affichée, pas de titre '
      '« À traiter »', (tester) async {
    sizeView(tester);
    final bid = _bid(
      status: 'COMPLETED',
      arrivalInstructions: 'Gare routière, quai 4',
    );

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('arrival-instructions-card')), findsOneWidget);
    expect(find.text('À traiter'), findsNothing);
    // Les consignes restent juste avant le voyageur.
    expect(
      tester.getTopLeft(find.byKey(const Key('arrival-instructions-card'))).dy,
      lessThan(tester.getTopLeft(find.byType(VoyageurContactCard)).dy),
    );
  });

  testWidgets('report en attente → tuile sous le titre « À traiter », la '
      'carte n\'est plus dans le corps', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      _host(
        _bid(reschedule: _reschedule(pending: true)),
        cancellationBloc,
        conversationOpenBloc,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('À traiter'), findsOneWidget);
    expect(find.byType(TripRescheduleCard), findsNothing);
    expect(
      tester.getTopLeft(_tile('Trajet reporté')).dy,
      greaterThan(tester.getTopLeft(find.text('À traiter')).dy),
    );
    expect(
      tester.getTopLeft(_tile('Trajet reporté')).dy,
      lessThan(tester.getTopLeft(find.byType(VoyageurContactCard)).dy),
    );
  });

  testWidgets('report déjà décidé → carte affichée, pas de titre', (
    tester,
  ) async {
    sizeView(tester);
    await tester.pumpWidget(
      _host(
        _bid(reschedule: _reschedule(pending: false)),
        cancellationBloc,
        conversationOpenBloc,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TripRescheduleCard), findsOneWidget);
    expect(find.text('À traiter'), findsNothing);
    expect(
      tester.getTopLeft(find.byType(TripRescheduleCard)).dy,
      lessThan(tester.getTopLeft(find.byType(VoyageurContactCard)).dy),
    );
  });

  testWidgets('une section ne démonte pas les suivantes quand « À traiter » '
      'apparaît', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      _host(_bid(status: 'IN_TRANSIT'), cancellationBloc, conversationOpenBloc),
    );
    await tester.pump(const Duration(seconds: 1));
    // Le stagger d'entrée est fini : un premier rebuild retire ses enveloppes.
    await tester.pumpWidget(
      _host(_bid(status: 'IN_TRANSIT'), cancellationBloc, conversationOpenBloc),
    );
    await tester.pump();
    final before = tester.element(find.byType(PaiementCard));

    await tester.pumpWidget(
      _host(
        _bid(
          status: 'IN_TRANSIT',
          recipientAppStatus: 'DECLINED',
          // La cellule d'absence apparaît aussi, sous la grille.
          departureAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        cancellationBloc,
        conversationOpenBloc,
      ),
    );
    await tester.pump();

    expect(find.text('À traiter'), findsOneWidget);
    expect(find.byType(DeliveryNoShowCtaCell), findsOneWidget);
    expect(tester.element(find.byType(PaiementCard)), same(before));
  });

  // ── « À traiter » : cartes d'alerte puis tuiles ───────────────────────────
  group('« À traiter » en tuiles', () {
    late _MockAnalyticsService analytics;

    setUp(() {
      analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<AnalyticsService>(analytics);
    });
    tearDown(() async => getIt.reset());

    BidModel declined({String status = 'IN_TRANSIT'}) =>
        _bid(status: status, recipientAppStatus: 'DECLINED');

    testWidgets('cartes d\'alerte d\'abord, puis la grille des tuiles, le tout '
        'avant le voyageur et hors de « Votre envoi »', (tester) async {
      sizeView(tester);
      final bid = _bid(
        status: 'IN_TRANSIT',
        recipientAppStatus: 'DECLINED',
        reschedule: _reschedule(pending: true),
        departureAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(find.text('À traiter'), findsOneWidget);
      final ys = [
        top(find.text('À traiter')),
        top(find.byType(DeliveryNoShowCtaCell)),
        top(_tile('Trajet reporté')),
        top(find.byType(VoyageurContactCard)),
        top(find.text('Votre envoi')),
      ];
      expect([...ys]..sort(), ys);
      // Report puis destinataire, sur la même ligne de la grille.
      expect(
        top(_tile('Destinataire à remplacer')),
        top(_tile('Trajet reporté')),
      );
      expect(
        tester.getTopLeft(_tile('Destinataire à remplacer')).dx,
        greaterThan(tester.getTopLeft(_tile('Trajet reporté')).dx),
      );
    });

    testWidgets('tuile : pastille ambre « Réponse attendue » et résumé court', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(declined(), cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      final badge = tester.widget<ToolStatusBadge>(
        find.descendant(
          of: _tile('Destinataire à remplacer'),
          matching: find.byType(ToolStatusBadge),
        ),
      );
      expect(badge.tone, ToolStatusTone.news);
      expect(badge.label, 'Réponse attendue');
      expect(
        find.descendant(
          of: _tile('Destinataire à remplacer'),
          matching: find.text('A refusé le colis'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('toucher la tuile ouvre son sheet et le compte', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(reschedule: _reschedule(pending: true)),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(_tile('Trajet reporté'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('donyBottomSheetFooter')),
          matching: find.byKey(const Key('reschedule-keep')),
        ),
        findsOneWidget,
      );
      expect(find.byType(TripRescheduleCard), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTileOpened,
          properties: {
            'tile': 'reschedule',
            'role': 'sender',
            'source': 'tile',
          },
        ),
      ).called(1);
    });

    testWidgets('mesure d\'affichage : une fois par colis et statut, malgré '
        'les relevés', (tester) async {
      sizeView(tester);
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(
          _host(declined(), cancellationBloc, conversationOpenBloc),
        );
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTodoTileShown,
          properties: {
            'tile': 'recipient',
            'role': 'sender',
            'status': 'IN_TRANSIT',
          },
        ),
      ).called(1);

      // Le colis change de statut : la tuile est de nouveau mesurée.
      await tester.pumpWidget(
        _host(
          declined(status: 'ARRIVED'),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTodoTileShown,
          properties: {
            'tile': 'recipient',
            'role': 'sender',
            'status': 'ARRIVED',
          },
        ),
      ).called(1);
    });

    testWidgets('sans demande à traiter : aucune mesure de tuile', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(_bid(), cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTodoTileShown,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  // ── Teintes, pastilles et résumés des tuiles ──────────────────────────────
  group('tuiles', () {
    Future<void> pumpBody(WidgetTester tester, BidModel bid) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    Color tint(WidgetTester tester, String label) {
      final tile = tester.widget<DonyActionTile>(_tile(label));
      return tile.color;
    }

    testWidgets('bleu pour Prévenir, Colis et Détails, terracotta pour '
        'Lieux', (tester) async {
      await pumpBody(
        tester,
        _bid(
          handoverAddress: const AddressData(
            label: '1 rue A',
            lat: 48.8,
            lng: 2.3,
          ),
        ),
      );
      final cs = Theme.of(tester.element(find.byType(ColisBillet))).colorScheme;
      expect(tint(tester, 'Prévenir Fatou'), cs.primary);
      expect(tint(tester, 'Colis et destinataire'), cs.primary);
      expect(tint(tester, 'Plus de détails'), cs.primary);
      expect(tint(tester, 'Lieux'), cs.secondary);
    });

    testWidgets('Prévenir : lien de suivi sans code, pas de pastille', (
      tester,
    ) async {
      await pumpBody(tester, _bid());
      final tile = tester.widget<DonyActionTile>(_tile('Prévenir Fatou'));
      expect(tile.subtitle, 'Envoyer le lien de suivi');
      expect(tile.badge, isNull);
    });

    testWidgets('Prévenir : code prêt et pastille « Code prêt »', (
      tester,
    ) async {
      await pumpBody(
        tester,
        _bid(status: 'IN_TRANSIT', confirmationCode: '482913'),
      );
      final tile = tester.widget<DonyActionTile>(_tile('Prévenir Fatou'));
      expect(tile.subtitle, 'Envoyer le code de retrait');
      expect(
        find.descendant(
          of: _tile('Prévenir Fatou'),
          matching: find.text('Code prêt'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Prévenir : code expiré, lien et pas de pastille', (
      tester,
    ) async {
      await pumpBody(
        tester,
        _bid(
          status: 'IN_TRANSIT',
          confirmationCode: '482913',
          pickupCodeRenewalNeeded: true,
        ),
      );
      final tile = tester.widget<DonyActionTile>(_tile('Prévenir Fatou'));
      expect(tile.subtitle, 'Envoyer le lien de suivi');
      expect(tile.badge, isNull);
    });

    testWidgets('Prévenir : code vide, ni « Code prêt » ni code dans le '
        'sous-titre', (tester) async {
      await pumpBody(tester, _bid(status: 'IN_TRANSIT', confirmationCode: ''));
      final tile = tester.widget<DonyActionTile>(_tile('Prévenir Fatou'));
      expect(tile.subtitle, 'Envoyer le lien de suivi');
      expect(tile.badge, isNull);
    });

    testWidgets('Colis : poids et destinataire en sous-titre', (tester) async {
      await pumpBody(tester, _bid());
      final tile = tester.widget<DonyActionTile>(
        _tile('Colis et destinataire'),
      );
      expect(tile.subtitle, '5 kg · pour Fatou');
    });

    testWidgets('Colis : sans destinataire, le poids seul', (tester) async {
      await pumpBody(tester, _bid(recipientName: null));
      final tile = tester.widget<DonyActionTile>(
        _tile('Colis et destinataire'),
      );
      expect(tile.subtitle, '5 kg');
    });

    testWidgets('Suivi : terracotta et résumé du hero', (tester) async {
      await pumpBody(
        tester,
        _bid(
          status: 'ARRIVED',
          arrivalInstructions: 'Gare routière, quai 4',
          handoverAddress: const AddressData(
            label: '1 rue A',
            lat: 48.8,
            lng: 2.3,
          ),
        ),
      );
      final cs = Theme.of(tester.element(find.byType(ColisBillet))).colorScheme;
      expect(tint(tester, 'Suivi'), cs.secondary);
      final tile = tester.widget<DonyActionTile>(_tile('Suivi'));
      final summary = SenderHeroCard.statusLine(
        tester.element(find.byType(ColisBillet)),
        _bid(
          status: 'ARRIVED',
          arrivalInstructions: 'Gare routière, quai 4',
          handoverAddress: const AddressData(
            label: '1 rue A',
            lat: 48.8,
            lng: 2.3,
          ),
        ),
      );
      expect(tile.subtitle, summary);
      expect(tile.badge, isNotNull);
    });

    testWidgets('pas de pastille « Étape en cours » avant la remise', (
      tester,
    ) async {
      await pumpBody(
        tester,
        _bid(
          handoverAddress: const AddressData(
            label: '1 rue A',
            lat: 48.8,
            lng: 2.3,
          ),
        ),
      );
      expect(tester.widget<DonyActionTile>(_tile('Lieux')).badge, isNull);
    });

    testWidgets('tuile Plus de détails : sous-titre fixe', (tester) async {
      await pumpBody(tester, _bid());
      expect(
        tester.widget<DonyActionTile>(_tile('Plus de détails')).subtitle,
        'Référence, dépôt, lien de suivi',
      );
    });
  });

  // ── Test 2: PENDING → pas de voyageur ni d'actions de suivi ─────────────────
  testWidgets('2 · PENDING → profil du voyageur sans bouton de contact, '
      'tuiles Colis et Détails seulement', (tester) async {
    sizeView(tester);
    final bid = _bid(status: 'PENDING');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    // En attente : on voit qui est le voyageur, sans pouvoir le joindre.
    expect(find.byType(VoyageurContactCard), findsOneWidget);
    expect(_contactIcon(VoyageurContactCard, 'message-circle'), findsNothing);
    expect(_contactIcon(VoyageurContactCard, 'phone'), findsNothing);
    expect(_tile('Prévenir Fatou'), findsNothing);
    expect(_tile('Colis et destinataire'), findsOneWidget);
    expect(_tile('Plus de détails'), findsOneWidget);
    expect(find.byType(DonyActionTile), findsNWidgets(2));
  });

  // ── Test 2 bis: ARRIVED → voyageur et tuile Suivi toujours visibles ─────────
  testWidgets('2 bis · ARRIVED → VoyageurContactCard et tuile Suivi restent '
      'affichés', (tester) async {
    sizeView(tester);
    final bid = _bid(
      status: 'ARRIVED',
      handoverAddress: const AddressData(label: '1 rue A', lat: 48.8, lng: 2.3),
    );

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(VoyageurContactCard), findsOneWidget);
    expect(_tile('Suivi'), findsOneWidget);
  });

  // ── Test 3: CANCELLED → voyageur sans contact, tuiles Colis et Détails ──────
  testWidgets('3 · CANCELLED → profil du voyageur sans bouton de contact', (
    tester,
  ) async {
    sizeView(tester);
    final bid = _bid(status: 'CANCELLED');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(VoyageurContactCard), findsOneWidget);
    expect(_contactIcon(VoyageurContactCard, 'message-circle'), findsNothing);
    // Le billet et la tuile Colis restent toujours présents.
    expect(find.byType(ColisBillet), findsOneWidget);
    expect(_tile('Colis et destinataire'), findsOneWidget);
  });

  // ── Destinataire qui a refusé : « À traiter », pas de tuile Prévenir ────────
  testWidgets('destinataire en refus → tuile « Destinataire à remplacer » sous '
      'À traiter, sans tuile Prévenir', (tester) async {
    sizeView(tester);
    final bid = _bid(status: 'IN_TRANSIT', recipientAppStatus: 'DECLINED');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('À traiter'), findsOneWidget);
    expect(find.byType(RecipientDeclinedBody), findsNothing);
    expect(
      tester.getTopLeft(_tile('Destinataire à remplacer')).dy,
      greaterThan(tester.getTopLeft(find.text('À traiter')).dy),
    );
    expect(_tile('Prévenir Fatou'), findsNothing);
  });

  // ── Absence à la livraison : un geste attendu, avant le voyageur ──────────
  testWidgets('colis parti → cellule « Le voyageur ne livre pas » sous « À '
      'traiter », avant le voyageur', (tester) async {
    sizeView(tester);
    final bid = _bid(
      status: 'IN_TRANSIT',
      departureAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(DeliveryNoShowCtaCell.shouldShow(bid), isTrue);
    expect(find.byType(DeliveryNoShowCtaCell), findsOneWidget);
    expect(find.text('À traiter'), findsOneWidget);
    final cellTop = tester.getTopLeft(find.byType(DeliveryNoShowCtaCell)).dy;
    expect(
      cellTop,
      greaterThan(tester.getBottomLeft(find.text('À traiter')).dy),
    );
    expect(
      cellTop,
      lessThan(tester.getTopLeft(find.byType(VoyageurContactCard)).dy),
    );
    expect(
      cellTop,
      lessThan(tester.getTopLeft(find.byType(DonyActionTileGrid)).dy),
    );
  });

  testWidgets('pas de cellule d\'absence tant que le signalement est '
      'impossible', (tester) async {
    sizeView(tester);
    await tester.pumpWidget(
      _host(_bid(status: 'PENDING'), cancellationBloc, conversationOpenBloc),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DeliveryNoShowCtaCell), findsNothing);
  });

  // ── Instructions de retrait : encart hors du hero ──────────────────────────
  // Le hero ne les montrait qu'en ARRIVED, et les perdait dès qu'une
  // contestation, une absence ou la livraison prenait sa place.
  for (final status in ['HANDED_OVER', 'ARRIVED', 'COMPLETED']) {
    testWidgets('$status + instructions → encart des instructions de retrait', (
      tester,
    ) async {
      sizeView(tester);
      final bid = _bid(
        status: status,
        arrivalInstructions: 'Gare routière, quai 4',
      );

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(const Key('arrival-instructions-card')),
        findsOneWidget,
      );
      expect(find.text('Gare routière, quai 4'), findsOneWidget);
    });
  }

  testWidgets('sans instructions → aucun encart', (tester) async {
    sizeView(tester);
    final bid = _bid(status: 'ARRIVED', arrivalInstructions: '  ');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('arrival-instructions-card')), findsNothing);
  });

  // ── Test 4: COMPLETED + senderHasRated=true → RatingDoneBadge ──────────────
  testWidgets('4 · COMPLETED + senderHasRated=true → RatingDoneBadge affiché', (
    tester,
  ) async {
    sizeView(tester);
    final bid = _bid(status: 'COMPLETED', senderHasRated: true);

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Évaluation envoyée'), findsOneWidget);
  });

  // ── Test 5: COMPLETED + senderHasRated=false → RatingDoneBadge absent ──────
  testWidgets('5 · COMPLETED + senderHasRated=false → RatingDoneBadge absent', (
    tester,
  ) async {
    sizeView(tester);
    final bid = _bid(status: 'COMPLETED');

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Évaluation envoyée'), findsNothing);
  });

  // ── Test 6: stagger désactivé après premier build (playEntrance=false) ──────
  testWidgets('6 · après la durée du stagger, playEntrance passe à false '
      'et le second rebuild ne rejoue pas l\'animation', (tester) async {
    sizeView(tester);
    final bid = _bid();

    await tester.pumpWidget(_host(bid, cancellationBloc, conversationOpenBloc));
    // Attendre plus longtemps que la durée totale du stagger
    // (60ms × 7 + 300ms + 50ms = 770ms).
    await tester.pump(const Duration(milliseconds: 900));

    // Le corps doit toujours rendre ses widgets normalement.
    expect(find.byType(ColisBillet), findsOneWidget);
    expect(find.byType(PaiementCard), findsOneWidget);
  });

  testWidgets(
    'anglais · COMPLETED + senderHasRated=true → "Rating sent" affiché',
    (tester) async {
      useEnglish();
      sizeView(tester);
      final bid = _bid(status: 'COMPLETED', senderHasRated: true);

      await tester.pumpWidget(
        _host(bid, cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Rating sent'), findsOneWidget);
    },
  );

  group('supplément de prix', () {
    const proposed = BidSupplement(
      id: 'sup-1',
      status: BidSupplementStatus.proposed,
      grossAmount: 17,
      blocksHandover: true,
    );

    const paid = BidSupplement(
      id: 'sup-2',
      status: BidSupplementStatus.paid,
      grossAmount: 17,
    );

    setUp(() {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerFactory<SupplementActionCubit>(
        () => SupplementActionCubit(_MockSupplementRepository(), analytics),
      );
    });

    tearDown(() async => getIt.reset());

    double scrollOffset(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    testWidgets('encart affiché sous le hero, sans défilement par défaut', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          _bid(supplement: proposed),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SupplementSenderCard), findsOneWidget);
      expect(scrollOffset(tester), 0);
    });

    testWidgets('supplément proposé → sous le titre « À traiter »', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(supplement: proposed),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('À traiter'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(SupplementSenderCard)).dy,
        greaterThan(tester.getTopLeft(find.text('À traiter')).dy),
      );
    });

    testWidgets('supplément payé → carte affichée, pas de titre', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(_bid(supplement: paid), cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SupplementSenderCard), findsOneWidget);
      expect(find.text('À traiter'), findsNothing);
    });

    testWidgets('?action=supplement avec un supplément payé : la carte est '
        'amenée à l\'écran', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          _bid(supplement: paid),
          cancellationBloc,
          conversationOpenBloc,
          focusSupplement: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('À traiter'), findsNothing);
      expect(scrollOffset(tester), greaterThan(0));
    });

    testWidgets('?action=supplement : l\'encart est amené à l\'écran', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          _bid(supplement: proposed),
          cancellationBloc,
          conversationOpenBloc,
          focusSupplement: true,
        ),
      );
      await tester.pump();
      // Défilement animé (300 ms) lancé après la première image.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(scrollOffset(tester), greaterThan(0));
    });

    testWidgets('sans supplément : pas d\'encart ni de défilement', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(),
          cancellationBloc,
          conversationOpenBloc,
          focusSupplement: true,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SupplementSenderCard), findsNothing);
      expect(scrollOffset(tester), 0);
    });
  });

  group('modification du colis', () {
    const open = BidAmendment(
      id: 'am-1',
      status: BidAmendmentStatus.proposed,
      rail: 'CASH',
      addedWeightKg: 3,
      grossAmount: 26.8,
    );

    const declined = BidAmendment(
      id: 'am-2',
      status: BidAmendmentStatus.declined,
      rail: 'CASH',
      addedWeightKg: 3,
      grossAmount: 26.8,
    );

    late _MockAnalyticsService analytics;

    setUp(() {
      analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt
        ..registerSingleton<AnalyticsService>(analytics)
        ..registerFactory<AmendmentActionCubit>(
          () => AmendmentActionCubit(_MockAmendmentRepository(), analytics),
        );
    });

    tearDown(() async => getIt.reset());

    double scrollOffset(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    Finder sheetCancel() => find.descendant(
      of: find.byKey(const Key('donyBottomSheetFooter')),
      matching: find.byKey(const Key('amendment-cancel-btn')),
    );

    testWidgets('demande ouverte → tuile « Modification du colis » sous « À '
        'traiter », pas de carte au corps, pas de défilement', (tester) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(amendments: const [open]),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AmendmentSenderCard), findsNothing);
      expect(find.text('À traiter'), findsOneWidget);
      final tile = _tile('Modification du colis');
      expect(tile, findsOneWidget);
      expect(
        tester.getTopLeft(tile).dy,
        greaterThan(tester.getTopLeft(find.text('À traiter')).dy),
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.textContaining('3 kg en plus'),
        ),
        findsOneWidget,
      );
      final badge = tester.widget<ToolStatusBadge>(
        find.descendant(of: tile, matching: find.byType(ToolStatusBadge)),
      );
      expect(badge.tone, ToolStatusTone.news);
      expect(scrollOffset(tester), 0);
    });

    testWidgets('modification, report et destinataire : trois tuiles dans '
        'l\'ordre des anciennes cartes', (tester) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(
            amendments: const [open],
            reschedule: _reschedule(pending: true),
            recipientAppStatus: 'DECLINED',
          ),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final grid = tester.widget<DonyActionTileGrid>(
        find.byKey(const ValueKey('todo-tiles')),
      );
      expect(grid.tiles.map((t) => t.key), const [
        Key('sender-todo-amendment'),
        Key('sender-todo-reschedule'),
        Key('sender-todo-recipient'),
      ]);
    });

    testWidgets('toucher la tuile ouvre le sheet de la modification', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(amendments: const [open]),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(_tile('Modification du colis'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AmendmentSenderCard), findsOneWidget);
      expect(sheetCancel(), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTileOpened,
          properties: {'tile': 'amendment', 'role': 'sender', 'source': 'tile'},
        ),
      ).called(1);
    });

    testWidgets('mesure à l\'affichage de la tuile : bid_amendment_viewed '
        '(surface tuile) et bid_detail_todo_tile_shown, une fois par statut '
        'de la demande malgré les relevés', (tester) async {
      sizeView(tester);
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(
          _host(
            _bid(amendments: const [open]),
            cancellationBloc,
            conversationOpenBloc,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentViewed,
          properties: {
            'role': 'sender',
            'status': 'PROPOSED',
            'surface': 'tile',
          },
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTodoTileShown,
          properties: {
            'tile': 'amendment',
            'role': 'sender',
            'status': 'ACCEPTED',
          },
        ),
      ).called(1);

      // Acceptée par le voyageur (mobile money) : nouveau statut, nouvelle
      // mesure de la demande ; le colis, lui, n'a pas changé de statut.
      await tester.pumpWidget(
        _host(
          _bid(
            amendments: const [
              BidAmendment(
                id: 'am-1',
                status: BidAmendmentStatus.paymentPending,
                rail: 'PAWAPAY',
                addedWeightKg: 3,
                grossAmount: 26.8,
              ),
            ],
          ),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentViewed,
          properties: {
            'role': 'sender',
            'status': 'PAYMENT_PENDING',
            'surface': 'tile',
          },
        ),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTodoTileShown,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets('demande close non acceptée → carte affichée, pas de titre', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(amendments: const [declined]),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AmendmentSenderCard), findsOneWidget);
      expect(find.text('À traiter'), findsNothing);
      expect(_tile('Modification du colis'), findsNothing);
      // La carte d'information garde sa mesure au montage, sans surface.
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentViewed,
          properties: {'role': 'sender', 'status': 'DECLINED'},
        ),
      ).called(1);
    });

    testWidgets('?action=amendment, réponse attendue : le sheet s\'ouvre '
        'directement, une seule fois, source link', (tester) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(amendments: const [open]),
          cancellationBloc,
          conversationOpenBloc,
          focusAmendment: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(sheetCancel(), findsOneWidget);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTileOpened,
          properties: {'tile': 'amendment', 'role': 'sender', 'source': 'link'},
        ),
      ).called(1);

      // Fermé puis relevé du colis : pas de réouverture.
      Navigator.of(tester.element(sheetCancel())).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(
          _bid(amendments: const [open]),
          cancellationBloc,
          conversationOpenBloc,
          focusAmendment: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(sheetCancel(), findsNothing);
    });

    // Le lien est consommé au premier colis chargé (le corps ne reçoit jamais
    // de squelette : l'écran affiche le sien) : une demande créée plus tard
    // (relevé périodique) n'ouvre pas de sheet toute seule.
    testWidgets('?action=amendment : pas de demande au chargement, demande '
        'créée ensuite, aucun sheet ne s\'ouvre', (tester) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(),
          cancellationBloc,
          conversationOpenBloc,
          focusAmendment: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(
          _bid(amendments: const [open]),
          cancellationBloc,
          conversationOpenBloc,
          focusAmendment: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(sheetCancel(), findsNothing);
      expect(_tile('Modification du colis'), findsOneWidget);
    });

    testWidgets('pastille de la tuile selon l\'état : « En attente »', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(amendments: const [open]),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final badge = tester.widget<ToolStatusBadge>(
        find.descendant(
          of: _tile('Modification du colis'),
          matching: find.byType(ToolStatusBadge),
        ),
      );
      expect(badge.label, 'En attente');
    });

    const commission = BidAmendment(
      id: 'am-3',
      status: BidAmendmentStatus.commissionPending,
      rail: 'CASH',
      addedWeightKg: 3,
      grossAmount: 26.8,
    );

    testWidgets('commission chez le voyageur : l\'expéditeur attend, carte '
        'd\'information hors de « À traiter », mesurée au montage', (
      tester,
    ) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(amendments: const [commission]),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AmendmentSenderCard), findsOneWidget);
      expect(find.text('MODIFICATION DU COLIS'), findsOneWidget);
      expect(find.text('À traiter'), findsNothing);
      expect(_tile('Modification du colis'), findsNothing);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.bidAmendmentViewed,
          properties: {'role': 'sender', 'status': 'COMMISSION_PENDING'},
        ),
      ).called(1);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.bidDetailTodoTileShown,
          properties: any(named: 'properties'),
        ),
      );
    });

    testWidgets('?action=amendment, commission chez le voyageur : défilement '
        'vers la carte, sans sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          _bid(amendments: const [commission]),
          cancellationBloc,
          conversationOpenBloc,
          focusAmendment: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(scrollOffset(tester), greaterThan(0));
      expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
    });

    testWidgets('?action=amendment, demande close : la carte d\'information '
        'est amenée à l\'écran, sans sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          _bid(amendments: const [declined]),
          cancellationBloc,
          conversationOpenBloc,
          focusAmendment: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(scrollOffset(tester), greaterThan(0));
      expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
    });

    testWidgets('modification autorisée sans demande : pas de carte, le '
        'bouton vit dans le sheet Colis', (tester) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(
          _bid(amendmentAllowed: true),
          cancellationBloc,
          conversationOpenBloc,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(AmendmentEntry.shouldShow(_bid(amendmentAllowed: true)), isTrue);
      expect(find.byType(AmendmentSenderCard), findsNothing);
      expect(find.text('À traiter'), findsNothing);
      expect(find.text('Ajouter des kilos ou des articles'), findsNothing);
    });

    testWidgets('sans modification : aucune carte', (tester) async {
      sizeView(tester);
      await tester.pumpWidget(
        _host(_bid(), cancellationBloc, conversationOpenBloc),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AmendmentSenderCard), findsNothing);
    });
  });
}

TripRescheduleInfo _reschedule({required bool pending}) => TripRescheduleInfo(
  id: 'r1',
  reason: 'FLIGHT_CANCELLED',
  previousDepartureDate: DateTime(2026, 10, 9),
  newDepartureDate: DateTime(2026, 10, 13),
  decisionPending: pending,
  decisionDeadline: DateTime(2026, 10, 12, 18),
);

/// Tuile de la grille « Votre envoi » portant [label].
Finder _tile(String label) => find.widgetWithText(DonyActionTile, label);

/// Bouton d'une carte de profil (appel ou message), repéré par son icône.
Finder _contactIcon(Type card, String icon) => find.descendant(
  of: find.byType(card),
  matching: find.byWidgetPredicate((w) => w is DonyIcon && w.name == icon),
);
