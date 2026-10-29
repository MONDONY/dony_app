import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_action_tile.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/rating_events_service.dart';
import 'package:dony/core/services/trip_arrival_events_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_amendment/amendment_accept_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_amendment/amendment_commission_flow.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_action_cubit.dart';
import 'package:dony/features/matching/bloc/bid_supplement/supplement_payment_cubit.dart';
import 'package:dony/features/matching/bloc/traveler_tracking_card_cubit.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/bid_amendment.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_supplement.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_info.dart';
import 'package:dony/features/matching/data/repositories/bid_amendment_repository.dart';
import 'package:dony/features/matching/data/repositories/bid_supplement_repository.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_details_content.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_locations_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_detail_body.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_tracking_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/ratings/data/rating_repository.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancellationBloc
    extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

class _MockConversationOpenBloc
    extends MockBloc<ConversationOpenEvent, ConversationOpenState>
    implements ConversationOpenBloc {}

class _MockRatingBloc extends MockBloc<RatingEvent, RatingState>
    implements RatingBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockRatingRepository extends Mock implements RatingRepository {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockSupplementPaymentCubit extends MockCubit<SupplementPaymentState>
    implements SupplementPaymentCubit {}

class _MockSupplementRepository extends Mock
    implements BidSupplementRepository {}

class _MockAmendmentRepository extends Mock implements BidAmendmentRepository {}

class _MockBidAcceptanceBloc
    extends MockBloc<BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

// ── Constants & fixtures ───────────────────────────────────────────────────────

const _kSenderId = 'sender-001';

BidModel _makeBid({
  BidPaymentMethod paymentMethod = BidPaymentMethod.cash,
  String status = 'ACCEPTED',
  DateTime? handoverDeadline,
  String? cancellationNoShowStatus,
  String? confirmationCode,
  bool pickupCodeRenewalNeeded = false,
  String? trackingToken,
  TravelerTrackingModel? travelerTracking,
  AddressData? handoverAddress,
  AddressData? deliveryAddress,
  String? recipientName,
  BidSupplement? supplement,
  List<BidAmendment> amendments = const [],
  TripRescheduleInfo? reschedule,
}) => BidModel(
  reschedule: reschedule,
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: _kSenderId,
  weightKg: 3,
  status: status,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
  paymentMethod: paymentMethod,
  handoverDeadline: handoverDeadline,
  cancellationNoShowStatus: cancellationNoShowStatus,
  confirmationCode: confirmationCode,
  pickupCodeRenewalNeeded: pickupCodeRenewalNeeded,
  trackingToken: trackingToken,
  travelerTracking: travelerTracking,
  handoverAddress: handoverAddress,
  deliveryAddress: deliveryAddress,
  recipientName: recipientName,
  supplement: supplement,
  amendments: amendments,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
);

UserModel _user(String id) => UserModel(
  id: id,
  roles: const ['SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<GoRouter> _pump(
  WidgetTester tester, {
  required BidModel bid,
  required _MockAuthBloc authBloc,
  bool openCodeRenewal = false,
  bool focusSupplement = false,
  bool focusAmendment = false,
  Size size = const Size(800, 3000),
}) async {
  await initializeDateFormatting('fr_FR');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: BidDetailScreen(
            bid: bid,
            openCodeRenewal: openCodeRenewal,
            focusSupplement: focusSupplement,
            focusAmendment: focusAmendment,
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/conversations/:id',
        builder: (_, _) => const Scaffold(body: Text('Conversation')),
      ),
      GoRoute(
        path: '/tracking',
        builder: (_, _) => const Scaffold(body: Text('Tracking')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  // Avance le temps pour que les animations flutter_animate (300ms fadeIn)
  // se terminent complètement, évitant les timers "pending" en fin de test.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(); // microtasks de _loadPaymentStatus
  return router;
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late _MockBidBloc bidBloc;
  late _MockBidAcceptanceBloc acceptanceBloc;
  late _MockCancellationBloc cancellationBloc;
  late _MockTrackingBloc trackingBloc;
  late _MockConversationOpenBloc conversationOpenBloc;
  late _MockRatingBloc ratingBloc;
  late _MockPaymentRepository paymentRepository;
  late _MockNotificationService notificationService;
  late StreamController<Map<String, dynamic>> pushes;

  setUpAll(() {
    // Requis par mocktail pour verify(() => bidBloc.add(any(that: isA<...>())))
    // (finding I1) — un event concret de refetch suffit comme fallback.
    registerFallbackValue(BidDetailRequested('fallback'));
  });

  setUp(() {
    bidBloc = _MockBidBloc();
    acceptanceBloc = _MockBidAcceptanceBloc();
    cancellationBloc = _MockCancellationBloc();
    trackingBloc = _MockTrackingBloc();
    conversationOpenBloc = _MockConversationOpenBloc();
    ratingBloc = _MockRatingBloc();
    paymentRepository = _MockPaymentRepository();
    notificationService = _MockNotificationService();
    pushes = StreamController<Map<String, dynamic>>.broadcast();
    when(
      () => notificationService.foregroundPushStream,
    ).thenAnswer((_) => pushes.stream);

    when(() => bidBloc.state).thenReturn(BidInitial());
    when(
      () => bidBloc.stream,
    ).thenAnswer((_) => const Stream<BidState>.empty());
    when(() => cancellationBloc.state).thenReturn(CancellationInitial());
    when(
      () => cancellationBloc.stream,
    ).thenAnswer((_) => const Stream<CancellationState>.empty());
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(
      () => trackingBloc.stream,
    ).thenAnswer((_) => const Stream<TrackingState>.empty());
    when(
      () => conversationOpenBloc.state,
    ).thenReturn(const ConversationOpenInitial());
    when(
      () => conversationOpenBloc.stream,
    ).thenAnswer((_) => const Stream<ConversationOpenState>.empty());
    when(() => ratingBloc.state).thenReturn(const RatingInitial());
    when(
      () => ratingBloc.stream,
    ).thenAnswer((_) => const Stream<RatingState>.empty());
    when(() => acceptanceBloc.state).thenReturn(acs.BidAcceptanceInitial());
    when(
      () => acceptanceBloc.stream,
    ).thenAnswer((_) => const Stream<acs.BidAcceptanceState>.empty());
    when(
      () => paymentRepository.getPaymentForBid(any()),
    ).thenAnswer((_) async => null);

    if (getIt.isRegistered<BidBloc>()) getIt.unregister<BidBloc>();
    if (getIt.isRegistered<BidAcceptanceBloc>()) {
      getIt.unregister<BidAcceptanceBloc>();
    }
    if (getIt.isRegistered<CancellationBloc>()) {
      getIt.unregister<CancellationBloc>();
    }
    if (getIt.isRegistered<TrackingBloc>()) getIt.unregister<TrackingBloc>();
    if (getIt.isRegistered<ConversationOpenBloc>()) {
      getIt.unregister<ConversationOpenBloc>();
    }
    if (getIt.isRegistered<RatingBloc>()) getIt.unregister<RatingBloc>();
    if (getIt.isRegistered<PaymentRepository>()) {
      getIt.unregister<PaymentRepository>();
    }

    getIt.registerFactory<BidBloc>(() => bidBloc);
    getIt.registerFactory<BidAcceptanceBloc>(() => acceptanceBloc);
    getIt.registerFactory<CancellationBloc>(() => cancellationBloc);
    getIt.registerFactory<TrackingBloc>(() => trackingBloc);
    getIt.registerFactory<ConversationOpenBloc>(() => conversationOpenBloc);
    getIt.registerFactory<RatingBloc>(() => ratingBloc);
    getIt.registerLazySingleton<PaymentRepository>(() => paymentRepository);
    if (getIt.isRegistered<NotificationService>()) {
      getIt.unregister<NotificationService>();
    }
    getIt.registerSingleton<NotificationService>(notificationService);
  });

  tearDown(() async {
    for (final unregister in [
      () => getIt.unregister<BidBloc>(),
      () => getIt.unregister<BidAcceptanceBloc>(),
      () => getIt.unregister<CancellationBloc>(),
      () => getIt.unregister<TrackingBloc>(),
      () => getIt.unregister<ConversationOpenBloc>(),
      () => getIt.unregister<RatingBloc>(),
      () => getIt.unregister<PaymentRepository>(),
      () => getIt.unregister<NotificationService>(),
    ]) {
      try {
        unregister();
      } on Object catch (_) {}
    }
    await pushes.close();
  });

  _MockAuthBloc senderAuth() {
    final authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(_user(_kSenderId)));
    when(
      () => authBloc.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    return authBloc;
  }

  void noDetailRequest() =>
      verifyNever(() => bidBloc.add(any(that: isA<BidDetailRequested>())));

  int detailRequests() =>
      verify(() => bidBloc.add(any(that: isA<BidDetailRequested>()))).callCount;

  group('Carte Paiement — état réel du paiement', () {
    testWidgets(
      'le paiement lu après coup (null puis échoué) met la carte à jour',
      (tester) async {
        final payment = Completer<PaymentModel?>();
        when(
          () => paymentRepository.getPaymentForBid(any()),
        ).thenAnswer((_) => payment.future);

        await _pump(
          tester,
          bid: _makeBid(
            status: 'PENDING',
            paymentMethod: BidPaymentMethod.stripe,
          ),
          authBloc: senderAuth(),
        );

        // Paiement pas encore lu : état par défaut de la carte, sans spinner.
        expect(find.text('Paiement échoué'), findsNothing);
        expect(find.textContaining('séquestré'), findsOneWidget);

        payment.complete(
          const PaymentModel(
            id: 'pay-1',
            bidId: 'bid-001',
            amount: 30,
            commissionAmount: 3,
            status: PaymentStatus.failed,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Paiement échoué'), findsOneWidget);
        expect(find.textContaining('séquestré'), findsNothing);
      },
    );
  });

  // La lecture du paiement (`GET /payments/bid`) ne nourrit que la vue
  // expéditeur (carte Paiement, barre collante) : le voyageur ne la déclenche
  // pas. Rôle non résolu (aucun utilisateur connu) : comportement d'avant.
  group('lecture du paiement selon le rôle', () {
    _MockAuthBloc viewer(String id) {
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(AuthAuthenticated(_user(id)));
      when(
        () => authBloc.stream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      return authBloc;
    }

    for (final status in ['PENDING', 'ACCEPTED', 'HANDED_OVER']) {
      testWidgets('voyageur · $status : aucun GET du paiement', (tester) async {
        await _pump(
          tester,
          bid: _makeBid(status: status, paymentMethod: BidPaymentMethod.stripe),
          authBloc: viewer('traveler-001'),
        );
        verifyNever(() => paymentRepository.getPaymentForBid(any()));
        // Le relevé suivant ne la lit pas non plus.
        await tester.pump(const Duration(seconds: 31));
        verifyNever(() => paymentRepository.getPaymentForBid(any()));
      });
    }

    for (final status in ['PENDING', 'ACCEPTED', 'HANDED_OVER']) {
      testWidgets('expéditeur · $status : le paiement est lu', (tester) async {
        await _pump(
          tester,
          bid: _makeBid(status: status, paymentMethod: BidPaymentMethod.stripe),
          authBloc: senderAuth(),
        );
        verify(() => paymentRepository.getPaymentForBid('bid-001')).called(1);
      });
    }

    // Arrivée par notification ou lien profond : `push('/bids/id')` sans
    // `extra` ouvre un colis squelette (sans expéditeur), le rôle n'est connu
    // qu'au chargement.
    group('colis squelette (notification, lien profond)', () {
      late StreamController<BidState> states;

      setUp(() {
        states = StreamController<BidState>.broadcast();
        when(() => bidBloc.stream).thenAnswer((_) => states.stream);
      });

      tearDown(() => states.close());

      Future<void> load(WidgetTester tester, String status) async {
        states.add(
          BidDetailLoaded(
            _makeBid(status: status, paymentMethod: BidPaymentMethod.stripe),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      for (final status in ['PENDING', 'HANDED_OVER']) {
        testWidgets('voyageur · $status : aucun GET du paiement, ni à '
            'l\'ouverture ni au chargement', (tester) async {
          await _pump(
            tester,
            bid: BidModel.skeleton('bid-001'),
            authBloc: viewer('traveler-001'),
          );
          verifyNever(() => paymentRepository.getPaymentForBid(any()));

          await load(tester, status);
          verifyNever(() => paymentRepository.getPaymentForBid(any()));
        });

        testWidgets('expéditeur · $status : un seul GET, au chargement', (
          tester,
        ) async {
          await _pump(
            tester,
            bid: BidModel.skeleton('bid-001'),
            authBloc: senderAuth(),
          );
          verifyNever(() => paymentRepository.getPaymentForBid(any()));

          await load(tester, status);
          verify(() => paymentRepository.getPaymentForBid('bid-001')).called(1);
        });
      }

      testWidgets('rôle non résolu : le paiement est lu au chargement', (
        tester,
      ) async {
        final authBloc = _MockAuthBloc();
        when(() => authBloc.state).thenReturn(const AuthInitial());
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => const Stream<AuthState>.empty());
        await _pump(
          tester,
          bid: BidModel.skeleton('bid-001'),
          authBloc: authBloc,
        );
        await load(tester, 'HANDED_OVER');
        verify(() => paymentRepository.getPaymentForBid('bid-001')).called(1);
      });
    });

    testWidgets('rôle non résolu (aucun utilisateur) : le paiement est lu', (
      tester,
    ) async {
      final authBloc = _MockAuthBloc();
      when(() => authBloc.state).thenReturn(const AuthInitial());
      when(
        () => authBloc.stream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      await _pump(
        tester,
        bid: _makeBid(paymentMethod: BidPaymentMethod.stripe),
        authBloc: authBloc,
      );
      verify(() => paymentRepository.getPaymentForBid('bid-001')).called(1);
    });
  });

  group('Annulation avant paiement', () {
    testWidgets(
      'BidCancelledBeforePayment → snackbar « Demande annulée » et sortie de la fiche',
      (tester) async {
        final states = StreamController<BidState>.broadcast();
        addTearDown(states.close);
        when(() => bidBloc.stream).thenAnswer((_) => states.stream);

        await _pump(
          tester,
          bid: _makeBid(
            status: 'AWAITING_PAYMENT',
            paymentMethod: BidPaymentMethod.stripe,
          ),
          authBloc: senderAuth(),
        );

        states.add(BidCancelledBeforePayment());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.text("Demande annulée. Rien n'a été débité."),
          findsOneWidget,
        );
        expect(find.text('Home'), findsOneWidget);
      },
    );
  });

  group('FLUTTER-CH — relecture du colis en attente du voyageur', () {
    // AWAITING_PAYMENT : le voyageur attend le séquestre de l'expéditeur (30
    // min) et doit voir le colis passer à ACCEPTED sans rien faire.
    for (final status in ['PENDING', 'PAYMENT_ESCROWED', 'AWAITING_PAYMENT']) {
      testWidgets('$status → relevé périodique toutes les 30 s', (
        tester,
      ) async {
        await _pump(
          tester,
          bid: _makeBid(status: status),
          authBloc: senderAuth(),
        );
        expect(detailRequests(), 1);

        await tester.pump(const Duration(seconds: 31));
        expect(detailRequests(), 1);
      });
    }

    testWidgets('REJECTED → aucun relevé périodique', (tester) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: senderAuth(),
      );
      expect(detailRequests(), 1);

      await tester.pump(const Duration(seconds: 31));
      noDetailRequest();
    });

    testWidgets('push → transmise au BidBloc avec ce colis et son data', (
      tester,
    ) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: senderAuth(),
      );
      expect(detailRequests(), 1);

      // Le filtre sur le bidId vit dans le BidBloc (bid_bloc_test.dart) :
      // l'écran transmet chaque push avec l'identifiant qu'il affiche.
      pushes.add({'type': 'PARCEL_RETURNED', 'bidId': 'bid-001'});
      await tester.pump();
      final events = verify(
        () => bidBloc.add(
          captureAny(that: isA<BidDetailExternalChangeDetected>()),
        ),
      ).captured.cast<BidDetailExternalChangeDetected>();
      expect(events, hasLength(1));
      expect(events.single.bidId, 'bid-001');
      expect(events.single.push, {
        'type': 'PARCEL_RETURNED',
        'bidId': 'bid-001',
      });
      noDetailRequest();
    });

    testWidgets('écran fermé → abonnement aux pushs annulé', (tester) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: senderAuth(),
      );
      expect(pushes.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(pushes.hasListener, isFalse);
    });
  });

  group('FLUTTER-D6 — trajet marqué arrivé', () {
    late TripArrivalEventsService arrivals;

    setUp(() {
      arrivals = TripArrivalEventsService();
      getIt.registerSingleton<TripArrivalEventsService>(arrivals);
    });

    tearDown(() async {
      getIt.unregister<TripArrivalEventsService>();
      await arrivals.dispose();
    });

    testWidgets('trajet de ce colis → relecture immédiate', (tester) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: senderAuth(),
      );
      expect(detailRequests(), 1);

      arrivals.notifyArrived('ann-001');
      await tester.pump();
      expect(detailRequests(), 1);
    });

    testWidgets('autre trajet → ignoré', (tester) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: senderAuth(),
      );
      expect(detailRequests(), 1);

      arrivals.notifyArrived('ann-999');
      await tester.pump();
      noDetailRequest();
    });
  });

  group('FLUTTER-FN — retour au premier plan', () {
    testWidgets('resumed → relecture du colis (push reçue en arrière-plan)', (
      tester,
    ) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'CANCELLED'),
        authBloc: senderAuth(),
      );
      expect(detailRequests(), 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      verifyNever(
        () => bidBloc.add(any(that: isA<BidDetailExternalChangeDetected>())),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      final events = verify(
        () => bidBloc.add(
          captureAny(that: isA<BidDetailExternalChangeDetected>()),
        ),
      ).captured.cast<BidDetailExternalChangeDetected>();
      expect(events, hasLength(1));
      expect(events.single.bidId, 'bid-001');
      expect(events.single.push, isNull);
    });

    testWidgets('écran fermé → plus de relecture à la reprise', (tester) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'CANCELLED'),
        authBloc: senderAuth(),
      );
      await tester.pumpWidget(const SizedBox());
      clearInteractions(bidBloc);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      verifyNever(
        () => bidBloc.add(any(that: isA<BidDetailExternalChangeDetected>())),
      );
    });
  });

  group('colis introuvable (404)', () {
    testWidgets(
      'BidNotFound → « Cette demande n\'existe plus » et accès à Mes envois',
      (tester) async {
        final states = StreamController<BidState>.broadcast();
        addTearDown(states.close);
        when(() => bidBloc.stream).thenAnswer((_) => states.stream);

        await _pump(
          tester,
          bid: BidModel.skeleton('bid-001'),
          authBloc: senderAuth(),
        );

        states.add(BidNotFound());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byKey(const Key('bid-detail-gone')), findsOneWidget);
        expect(find.text("Cette demande n'existe plus"), findsOneWidget);
        expect(find.text('Home'), findsNothing, reason: 'reste sur l\'écran');

        await tester.tap(find.text('Voir mes envois'));
        await tester.pumpAndSettle();
        expect(find.text('Tracking'), findsOneWidget);
      },
    );

    testWidgets('BidNotFound → plus de relevé périodique', (tester) async {
      final states = StreamController<BidState>.broadcast();
      addTearDown(states.close);
      when(() => bidBloc.stream).thenAnswer((_) => states.stream);

      await _pump(
        tester,
        bid: _makeBid(status: 'PENDING'),
        authBloc: senderAuth(),
      );
      states.add(BidNotFound());
      await tester.pump(const Duration(milliseconds: 400));
      clearInteractions(bidBloc);

      await tester.pump(const Duration(seconds: 31));
      noDetailRequest();
    });
  });

  // FLUTTER-G2 (back #461) : la notification CONFIRMATION_CODE_REQUESTED
  // ouvre la fiche avec `?action=new-code`, qui propose aussitôt la
  // régénération du code à l'expéditeur.
  group('?action=new-code', () {
    const sheetTitle = 'Le voyageur demande un nouveau code';

    void detailLoads(BidModel bid) => when(
      () => bidBloc.stream,
    ).thenAnswer((_) => Stream<BidState>.value(BidDetailLoaded(bid)));

    testWidgets('expéditeur, code à renouveler : la feuille s\'ouvre', (
      tester,
    ) async {
      final bid = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        status: 'IN_TRANSIT',
        pickupCodeRenewalNeeded: true,
      );
      detailLoads(bid);
      await _pump(
        tester,
        bid: bid,
        authBloc: senderAuth(),
        openCodeRenewal: true,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(sheetTitle), findsOneWidget);
      expect(
        find.byKey(const Key('pickup-code-renewal-generate')),
        findsOneWidget,
      );
    });

    testWidgets('code encore valide : pas de feuille', (tester) async {
      final bid = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        status: 'IN_TRANSIT',
        confirmationCode: '123456',
      );
      detailLoads(bid);
      await _pump(
        tester,
        bid: bid,
        authBloc: senderAuth(),
        openCodeRenewal: true,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(sheetTitle), findsNothing);
    });

    testWidgets('sans le paramètre : pas de feuille', (tester) async {
      final bid = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        status: 'IN_TRANSIT',
        pickupCodeRenewalNeeded: true,
      );
      detailLoads(bid);
      await _pump(tester, bid: bid, authBloc: senderAuth());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(sheetTitle), findsNothing);
    });
  });

  // Notification BID_SUPPLEMENT_REQUESTED : `?action=supplement` est transmis
  // à la vue expéditeur, qui amène l'encart du supplément à l'écran.
  testWidgets('?action=supplement : transmis à la vue expéditeur', (
    tester,
  ) async {
    final bid = _makeBid(paymentMethod: BidPaymentMethod.stripe);
    await _pump(
      tester,
      bid: bid,
      authBloc: senderAuth(),
      focusSupplement: true,
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester
          .widget<SenderDetailBody>(find.byType(SenderDetailBody))
          .focusSupplement,
      isTrue,
    );
  });

  // Le résolveur de notifications envoie aussi le voyageur sur
  // `?action=amendment` (BID_AMENDMENT_REQUESTED|REMINDER|ACCEPTED) et
  // `?action=supplement` : la vue voyageur reçoit les deux paramètres.
  group('?action= côté voyageur', () {
    setUp(() {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerFactory<SupplementActionCubit>(
        () => SupplementActionCubit(_MockSupplementRepository(), analytics),
      );
      final amendmentRepo = _MockAmendmentRepository();
      getIt
        ..registerFactory<AmendmentActionCubit>(
          () => AmendmentActionCubit(amendmentRepo, analytics),
        )
        ..registerFactory<AmendmentAcceptCubit>(
          () => AmendmentAcceptCubit(
            amendmentRepo,
            analytics,
            AmendmentCommissionFlow(amendmentRepo, analytics),
          ),
        );
    });

    tearDown(() {
      if (getIt.isRegistered<SupplementActionCubit>()) {
        getIt.unregister<SupplementActionCubit>();
      }
      if (getIt.isRegistered<AmendmentActionCubit>()) {
        getIt.unregister<AmendmentActionCubit>();
      }
      if (getIt.isRegistered<AmendmentAcceptCubit>()) {
        getIt.unregister<AmendmentAcceptCubit>();
      }
    });

    _MockAuthBloc travelerViewer() {
      final authBloc = _MockAuthBloc();
      when(
        () => authBloc.state,
      ).thenReturn(AuthAuthenticated(_user('traveler-001')));
      when(
        () => authBloc.stream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      return authBloc;
    }

    for (final (supplement, amendment) in [(true, false), (false, true)]) {
      testWidgets(
        'supplement=$supplement amendment=$amendment : transmis à la vue '
        'voyageur',
        (tester) async {
          await _pump(
            tester,
            bid: _makeBid(paymentMethod: BidPaymentMethod.stripe),
            authBloc: travelerViewer(),
            focusSupplement: supplement,
            focusAmendment: amendment,
          );
          await tester.pump(const Duration(milliseconds: 500));

          final body = tester.widget<TravelerDetailBody>(
            find.byType(TravelerDetailBody),
          );
          expect(body.focusSupplement, supplement);
          expect(body.focusAmendment, amendment);
          expect(find.byType(SenderDetailBody), findsNothing);
        },
      );
    }

    testWidgets('?action=supplement : la carte du supplément est amenée à '
        'l\'écran', (tester) async {
      final bid = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        supplement: const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.proposed,
          netAmount: 15,
          commissionAmount: 2,
          grossAmount: 17,
          blocksHandover: true,
        ),
      );
      await _pump(
        tester,
        bid: bid,
        authBloc: travelerViewer(),
        focusSupplement: true,
        size: const Size(800, 700),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SupplementTravelerCard), findsOneWidget);
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(offset, greaterThan(0));
      // Le haut de la carte est dans la fenêtre visible, pas seulement
      // « ça a défilé ».
      final top = tester.getTopLeft(find.byType(SupplementTravelerCard)).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(top, lessThan(700));
    });

    // Notifications BID_SUPPLEMENT_DECLINED / EXPIRED : la carte du supplément
    // refusé ou expiré, avec « Le colis ne correspond pas », est amenée à
    // l'écran.
    for (final status in [
      BidSupplementStatus.declined,
      BidSupplementStatus.expired,
    ]) {
      testWidgets('?action=supplement (${status.name}) : la carte du '
          'supplément clos est amenée à l\'écran', (tester) async {
        final bid = _makeBid(
          paymentMethod: BidPaymentMethod.stripe,
          supplement: BidSupplement(
            id: 'sup-1',
            status: status,
            netAmount: 15,
            commissionAmount: 2,
            grossAmount: 17,
          ),
        );
        await _pump(
          tester,
          bid: bid,
          authBloc: travelerViewer(),
          focusSupplement: true,
          size: const Size(800, 700),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(SupplementTravelerCard), findsOneWidget);
        final offset = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels;
        expect(offset, greaterThan(0));
        final top = tester.getTopLeft(find.byType(SupplementTravelerCard)).dy;
        expect(top, greaterThanOrEqualTo(0));
        expect(top, lessThan(700));
      });
    }

    for (final status in [
      BidAmendmentStatus.proposed,
      BidAmendmentStatus.declined,
    ]) {
      testWidgets('?action=amendment (${status.name}) : la carte de la '
          'modification est amenée à l\'écran', (tester) async {
        final bid = _makeBid(
          paymentMethod: BidPaymentMethod.stripe,
          amendments: [
            BidAmendment(
              id: 'am-1',
              status: status,
              rail: 'CASH',
              addedWeightKg: 3,
              grossAmount: 26.8,
              netAmount: 23.5,
              commissionAmount: 3.3,
              blocksHandover: status.isOpen,
            ),
          ],
        );
        await _pump(
          tester,
          bid: bid,
          authBloc: travelerViewer(),
          focusAmendment: true,
          size: const Size(800, 700),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AmendmentTravelerCard), findsOneWidget);
        final offset = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels;
        expect(offset, greaterThan(0));
        final top = tester.getTopLeft(find.byType(AmendmentTravelerCard)).dy;
        expect(top, greaterThanOrEqualTo(0));
        expect(top, lessThan(700));
      });
    }

    testWidgets('sans paramètre : pas de défilement vers la modification', (
      tester,
    ) async {
      final bid = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        amendments: [
          const BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.proposed,
            rail: 'CASH',
            addedWeightKg: 3,
            grossAmount: 26.8,
            netAmount: 23.5,
            commissionAmount: 3.3,
            blocksHandover: true,
          ),
        ],
      );
      await _pump(
        tester,
        bid: bid,
        authBloc: travelerViewer(),
        size: const Size(800, 700),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(offset, 0);
    });
  });

  // ── Fiche expéditeur en tuiles : vrai écran ───────────────────────────────
  // Les sheets des tuiles s'ouvrent sur le navigateur racine : chaque tuile
  // doit fonctionner avec les seuls BLoCs que l'écran fournit.
  group('fiche expéditeur en tuiles', () {
    const handover = AddressData(label: '1 rue A, Paris', lat: 48.8, lng: 2.3);
    const delivery = AddressData(
      label: 'ACI 2000, Dakar',
      lat: 14.7,
      lng: -17.4,
    );
    const tracking = TravelerTrackingModel(
      status: TravelerTrackingStatus.enRoute,
      nearestCity: 'Lyon',
      progressPct: 40,
    );
    late StreamController<BidState> states;

    BidModel acceptedBid({String? confirmationCode}) => _makeBid(
      paymentMethod: BidPaymentMethod.stripe,
      trackingToken: 'tok-abc',
      handoverAddress: handover,
      deliveryAddress: delivery,
      recipientName: 'Awa',
      confirmationCode: confirmationCode,
    );

    BidModel inTransitBid({String? confirmationCode}) => _makeBid(
      paymentMethod: BidPaymentMethod.stripe,
      status: 'IN_TRANSIT',
      trackingToken: 'tok-abc',
      travelerTracking: tracking,
      handoverAddress: handover,
      deliveryAddress: delivery,
      recipientName: 'Awa',
      confirmationCode: confirmationCode,
    );

    setUp(() {
      states = StreamController<BidState>.broadcast();
      when(() => bidBloc.stream).thenAnswer((_) => states.stream);
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerFactory<TravelerTrackingCardCubit>(
        () => TravelerTrackingCardCubit(analytics: analytics),
      );
      getIt.registerFactory<SupplementActionCubit>(
        () => SupplementActionCubit(_MockSupplementRepository(), analytics),
      );
      // Le bouton « Payer » de la barre du bas crée son propre cubit.
      final payment = _MockSupplementPaymentCubit();
      when(() => payment.state).thenReturn(const SupplementPaymentState());
      getIt.registerFactory<SupplementPaymentCubit>(() => payment);
    });

    tearDown(() async {
      await states.close();
      if (getIt.isRegistered<TravelerTrackingCardCubit>()) {
        getIt.unregister<TravelerTrackingCardCubit>();
      }
      if (getIt.isRegistered<SupplementActionCubit>()) {
        getIt.unregister<SupplementActionCubit>();
      }
      if (getIt.isRegistered<SupplementPaymentCubit>()) {
        getIt.unregister<SupplementPaymentCubit>();
      }
    });

    Finder tile(String label) => find.widgetWithText(DonyActionTile, label);

    Future<void> closeSheet(WidgetTester tester) async {
      Navigator.of(
        tester.element(find.byType(DonyActionTile).first),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
    }

    for (final (name, makeBid, tiles)
        in <(String, BidModel Function(), List<(String, Finder)>)>[
          (
            'ACCEPTED',
            () => acceptedBid(),
            [
              ('Prévenir Awa', find.byType(PrevenirDestinataireBody)),
              ('Lieux', find.byType(ParcelLocationsCard)),
              ('Colis et destinataire', find.byType(ColisDestinataireCard)),
              ('Plus de détails', find.byType(BidDetailsContent)),
            ],
          ),
          (
            'IN_TRANSIT',
            () => inTransitBid(),
            [
              ('Prévenir Awa', find.byType(PrevenirDestinataireBody)),
              ('Suivi', find.byType(TravelerTrackingCard)),
              ('Colis et destinataire', find.byType(ColisDestinataireCard)),
              ('Plus de détails', find.byType(BidDetailsContent)),
            ],
          ),
        ]) {
      testWidgets('$name : tapping each tile opens its sheet without '
          'ProviderNotFoundException', (tester) async {
        await _pump(tester, bid: makeBid(), authBloc: senderAuth());
        for (final (label, content) in tiles) {
          expect(content, findsNothing, reason: '$label : pas encore ouvert');
          await tester.tap(tile(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          expect(content, findsOneWidget, reason: label);
          await closeSheet(tester);
          expect(content, findsNothing, reason: '$label : refermé');
        }
      });
    }

    testWidgets('IN_TRANSIT shows billet, voyageur, paiement then 4 tiles, '
        'no hero, no quick actions', (tester) async {
      await _pump(tester, bid: inTransitBid(), authBloc: senderAuth());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SenderHeroCard), findsNothing);
      // Ni rangée « Suivi du colis / Partager le suivi » dans le corps (le
      // bouton de la barre du bas, lui, reste).
      final body = find.byType(SenderDetailBody);
      expect(
        find.descendant(of: body, matching: find.text('Suivi du colis')),
        findsNothing,
      );
      expect(
        find.descendant(of: body, matching: find.text('Partager le suivi')),
        findsNothing,
      );
      expect(find.byType(TravelerTrackingCard), findsNothing);
      expect(find.byType(BidDetailsContent), findsNothing);
      expect(find.byType(DonyActionTile), findsNWidgets(4));

      double top(Finder f) => tester.getTopLeft(f).dy;
      final billet = top(find.byType(ColisBillet));
      final voyageur = top(find.byType(VoyageurContactCard));
      final paiement = top(find.byType(PaiementCard));
      final title = top(find.text('Votre envoi'));
      final firstTile = top(find.byType(DonyActionTile).first);
      expect(billet, lessThan(voyageur));
      expect(voyageur, lessThan(paiement));
      expect(paiement, lessThan(title));
      expect(title, lessThan(firstTile));
    });

    testWidgets('À traiter header only when an action card shows', (
      tester,
    ) async {
      await _pump(tester, bid: inTransitBid(), authBloc: senderAuth());
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('À traiter'), findsNothing);
    });

    testWidgets('À traiter header shows above the action card', (tester) async {
      final overdue = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        handoverDeadline: DateTime.now().subtract(const Duration(days: 1)),
        trackingToken: 'tok-abc',
        recipientName: 'Awa',
      );
      await _pump(tester, bid: overdue, authBloc: senderAuth());
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SenderHeroCard), findsOneWidget);
      expect(find.text('À traiter'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(SenderHeroCard)).dy,
        greaterThan(tester.getTopLeft(find.text('À traiter')).dy),
      );
      expect(
        tester.getTopLeft(find.text('À traiter')).dy,
        greaterThan(tester.getTopLeft(find.byType(ColisBillet)).dy),
      );
      expect(
        tester.getTopLeft(find.byType(VoyageurContactCard)).dy,
        greaterThan(tester.getTopLeft(find.byType(SenderHeroCard)).dy),
      );
    });

    testWidgets('supplement focus still scrolls to the supplement card', (
      tester,
    ) async {
      final bid = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        supplement: const BidSupplement(
          id: 'sup-1',
          status: BidSupplementStatus.proposed,
          grossAmount: 17,
          blocksHandover: true,
        ),
      );
      await _pump(
        tester,
        bid: bid,
        authBloc: senderAuth(),
        focusSupplement: true,
        size: const Size(800, 700),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SupplementSenderCard), findsOneWidget);
      final offset = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      expect(offset, greaterThan(0));
    });

    // Notification de modification côté expéditeur, demande ouverte : le sheet
    // de la tuile s'ouvre de lui-même, avec les BLoCs de l'écran.
    testWidgets('?action=amendment opens the amendment tile sheet with the '
        'screen BLoCs', (tester) async {
      getIt.registerFactory<AmendmentActionCubit>(
        () => AmendmentActionCubit(
          _MockAmendmentRepository(),
          _MockAnalyticsService(),
        ),
      );
      addTearDown(() => getIt.unregister<AmendmentActionCubit>());
      final bid = _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        amendments: const [
          BidAmendment(
            id: 'am-1',
            status: BidAmendmentStatus.proposed,
            rail: 'CASH',
            addedWeightKg: 3,
            grossAmount: 26.8,
            blocksHandover: true,
          ),
        ],
      );
      await _pump(
        tester,
        bid: bid,
        authBloc: senderAuth(),
        focusAmendment: true,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final footer = find.byKey(const Key('donyBottomSheetFooter'));
      final cancel = find.descendant(
        of: footer,
        matching: find.byKey(const Key('amendment-cancel-btn')),
      );
      expect(cancel, findsOneWidget);
      expect(find.byType(AmendmentSenderCard), findsOneWidget);
      expect(tester.element(cancel).read<BidBloc>(), same(bidBloc));

      await closeSheet(tester);
      expect(cancel, findsNothing);
      expect(tile('Modification du colis'), findsOneWidget);
    });

    group('trajet reporté depuis la tuile', () {
      late StreamController<CancellationState> cancellation;

      TripRescheduleInfo reschedule({required bool pending}) =>
          TripRescheduleInfo(
            id: 'r1',
            reason: 'FLIGHT_CANCELLED',
            previousDepartureDate: DateTime(2026, 10, 9),
            newDepartureDate: DateTime(2026, 10, 13),
            decisionPending: pending,
            decisionDeadline: DateTime.utc(2026, 10, 12, 16),
          );

      BidModel rescheduled({required bool pending}) => _makeBid(
        paymentMethod: BidPaymentMethod.stripe,
        reschedule: reschedule(pending: pending),
      );

      setUp(() {
        cancellation = StreamController<CancellationState>.broadcast();
        when(
          () => cancellationBloc.stream,
        ).thenAnswer((_) => cancellation.stream);
      });

      tearDown(() => cancellation.close());

      Future<void> openRescheduleSheet(WidgetTester tester) async {
        await _pump(
          tester,
          bid: rescheduled(pending: true),
          authBloc: senderAuth(),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(tile('Trajet reporté'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('reschedule-keep')), findsOneWidget);
      }

      testWidgets('« Garder mon colis » : la feuille se ferme, la confirmation '
          'de l\'écran est visible, et la relecture ne referme rien de plus', (
        tester,
      ) async {
        await openRescheduleSheet(tester);

        await tester.tap(find.byKey(const Key('reschedule-keep')));
        await tester.pump();
        cancellation.add(RescheduleKept());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('reschedule-keep')), findsNothing);
        expect(
          find
              .text("C'est noté : votre colis part à la nouvelle date.")
              .hitTestable(),
          findsOneWidget,
        );

        states.add(BidDetailLoaded(rescheduled(pending: false)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SenderDetailBody), findsOneWidget);
        expect(tile('Trajet reporté'), findsNothing);
      });

      testWidgets('décision refusée : l\'erreur est visible par-dessus la '
          'feuille, une seule fois, et la feuille reste ouverte', (
        tester,
      ) async {
        await openRescheduleSheet(tester);

        await tester.tap(find.byKey(const Key('reschedule-keep')));
        await tester.pump();
        const error = ConflictException(
          'trop tard',
          code: 'reschedule-decision-closed',
        );
        cancellation.add(CancellationError(error));
        await tester.pumpAndSettle();

        final message = ErrorPresenter.resolve(error).message;
        expect(tester.takeException(), isNull);
        expect(find.text(message), findsOneWidget);
        expect(find.text(message).hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('reschedule-keep')), findsOneWidget);
      });
    });

    testWidgets('tiles recompute after a polling refresh from ACCEPTED to '
        'HANDED_OVER', (tester) async {
      await _pump(tester, bid: acceptedBid(), authBloc: senderAuth());
      expect(tile('Lieux'), findsOneWidget);
      expect(tile('Suivi'), findsNothing);

      states.add(
        BidDetailLoaded(
          _makeBid(
            paymentMethod: BidPaymentMethod.stripe,
            status: 'HANDED_OVER',
            trackingToken: 'tok-abc',
            travelerTracking: tracking,
            handoverAddress: handover,
            deliveryAddress: delivery,
            recipientName: 'Awa',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tile('Suivi'), findsOneWidget);
      expect(tile('Lieux'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening a tile then receiving a refresh throws nothing', (
      tester,
    ) async {
      await _pump(tester, bid: acceptedBid(), authBloc: senderAuth());
      await tester.tap(tile('Prévenir Awa'));
      await tester.pumpAndSettle();
      expect(find.byType(PrevenirDestinataireBody), findsOneWidget);

      // Le colis est remis pendant que le sheet est ouvert : la liste des
      // tuiles change (Lieux devient Suivi), le sheet reste debout.
      states.add(BidDetailLoaded(inTransitBid(confirmationCode: '482913')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(PrevenirDestinataireBody), findsOneWidget);
      expect(find.text('Envoyer le code sur WhatsApp'), findsOneWidget);
    });
  });

  group('FLUTTER-HQ — note envoyée depuis une autre instance de RatingBloc', () {
    const travelerId = 'traveler-001';
    late RatingEventsService ratingEvents;
    late _MockRatingRepository ratingRepository;
    late StreamController<BidState> bidStates;
    RatingBloc? rootBloc;

    // Instance racine (app.dart), distincte de celle de l'écran : c'est
    // elle que l'invite automatique de main_shell.dart utilise. Créée dans
    // le corps du test, pour vivre dans la zone du temps simulé.
    RatingBloc root() => rootBloc ??= RatingBloc(
      ratingRepository,
      makeDisabledAnalytics(MockAnalyticsBackend()),
      ratingEvents: ratingEvents,
    );

    BidModel completedBid({
      bool senderHasRated = false,
      bool travelerHasRated = false,
    }) => BidModel(
      id: 'bid-001',
      announcementId: 'ann-001',
      senderId: _kSenderId,
      travelerId: travelerId,
      travelerName: 'Moussa',
      weightKg: 3,
      status: 'COMPLETED',
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
      paymentMethod: BidPaymentMethod.cash,
      senderHasRated: senderHasRated,
      travelerHasRated: travelerHasRated,
    );

    /// Le serveur renvoie [fresh] à chaque relecture demandée par l'écran.
    void serverReturns(BidModel fresh) {
      when(
        () => bidBloc.add(any(that: isA<BidDetailRequested>())),
      ).thenAnswer((_) => bidStates.add(BidDetailLoaded(fresh)));
    }

    setUp(() {
      ratingEvents = RatingEventsService();
      getIt.registerSingleton<RatingEventsService>(ratingEvents);
      ratingRepository = _MockRatingRepository();
      bidStates = StreamController<BidState>.broadcast();
      when(() => bidBloc.stream).thenAnswer((_) => bidStates.stream);
      rootBloc = null;
    });

    tearDown(() async {
      getIt.unregister<RatingEventsService>();
      await rootBloc?.close();
      await bidStates.close();
      await ratingEvents.dispose();
    });

    _MockAuthBloc travelerAuth() {
      final authBloc = _MockAuthBloc();
      when(
        () => authBloc.state,
      ).thenReturn(AuthAuthenticated(_user(travelerId)));
      when(
        () => authBloc.stream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      return authBloc;
    }

    testWidgets(
      'expéditeur : note via l\'invite racine → « Noter le voyageur » disparaît',
      (tester) async {
        serverReturns(completedBid());
        await _pump(tester, bid: completedBid(), authBloc: senderAuth());
        await tester.pump();
        expect(find.text('Noter le voyageur'), findsOneWidget);

        when(
          () => ratingRepository.submitRating(bidId: 'bid-001', stars: 5),
        ).thenAnswer((_) async {});
        serverReturns(completedBid(senderHasRated: true));
        root().add(const RatingSubmitRequested(bidId: 'bid-001', stars: 5));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Noter le voyageur'), findsNothing);
      },
    );

    testWidgets(
      'expéditeur : 409 « Déjà noté » → colis relu, le bouton disparaît',
      (tester) async {
        serverReturns(completedBid());
        await _pump(tester, bid: completedBid(), authBloc: senderAuth());
        await tester.pump();
        expect(find.text('Noter le voyageur'), findsOneWidget);
        final before = detailRequests();
        expect(before, greaterThanOrEqualTo(1));

        when(
          () => ratingRepository.submitRating(bidId: 'bid-001', stars: 4),
        ).thenThrow(const ConflictException('Conflict', code: 'already-rated'));
        serverReturns(completedBid(senderHasRated: true));
        root().add(const RatingSubmitRequested(bidId: 'bid-001', stars: 4));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(detailRequests(), 1);
        expect(find.text('Noter le voyageur'), findsNothing);
      },
    );

    testWidgets('voyageur : note de l\'expéditeur via l\'invite racine → '
        'badge « Évaluation envoyée » affiché', (tester) async {
      serverReturns(completedBid());
      await _pump(tester, bid: completedBid(), authBloc: travelerAuth());
      await tester.pump();
      expect(find.byType(RatingDoneBadge), findsNothing);

      when(
        () => ratingRepository.submitTravelerRating(bidId: 'bid-001', stars: 5),
      ).thenAnswer((_) async {});
      serverReturns(completedBid(travelerHasRated: true));
      root().add(
        const TravelerRatingSubmitRequested(bidId: 'bid-001', stars: 5),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RatingDoneBadge), findsOneWidget);
    });

    testWidgets('note d\'un autre colis → aucune relecture', (tester) async {
      serverReturns(completedBid());
      await _pump(tester, bid: completedBid(), authBloc: senderAuth());
      await tester.pump();
      expect(detailRequests(), greaterThanOrEqualTo(1));

      ratingEvents.notifyRated('bid-999');
      await tester.pump();
      noDetailRequest();
    });

    testWidgets('écran fermé → abonnement au signal annulé', (tester) async {
      serverReturns(completedBid());
      await _pump(tester, bid: completedBid(), authBloc: senderAuth());
      await tester.pumpWidget(const SizedBox());
      expect(() => ratingEvents.notifyRated('bid-001'), returnsNormally);
      await tester.pump();
    });
  });
}
