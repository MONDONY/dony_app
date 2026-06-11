import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/core/di/injection.dart';
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
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/bid_detail_screen.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_bloc.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_state.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:dony/features/ratings/bloc/rating_bloc.dart';
import 'package:dony/features/ratings/bloc/rating_event.dart';
import 'package:dony/features/ratings/bloc/rating_state.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockBidAcceptanceBloc
    extends MockBloc<BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

// ── Constants & fixtures ───────────────────────────────────────────────────────

const _kSenderId = 'sender-001';
const _kTravelerId = 'traveler-001';

BidModel _makeBid({
  BidPaymentMethod paymentMethod = BidPaymentMethod.cash,
  String status = 'ACCEPTED',
  DateTime? handoverWindowEnd,
  String? cancellationNoShowStatus,
}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: _kSenderId,
  weightKg: 3,
  status: status,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
  paymentMethod: paymentMethod,
  handoverWindowEnd: handoverWindowEnd,
  cancellationNoShowStatus: cancellationNoShowStatus,
);

UserModel _user(String id) => UserModel(
  id: id,
  roles: const ['SENDER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
  stripeAccountStatus: 'NOT_CREATED',
);

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  required BidModel bid,
  required _MockAuthBloc authBloc,
}) async {
  await initializeDateFormatting('fr_FR');
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: BidDetailScreen(bid: bid),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/conversations/:id',
        builder: (_, __) => const Scaffold(body: Text('Conversation')),
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
  // Avance le temps pour que les animations flutter_animate (300ms fadeIn)
  // se terminent complètement, évitant les timers "pending" en fin de test.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(); // microtasks de _loadPaymentStatus
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

  setUp(() {
    bidBloc = _MockBidBloc();
    acceptanceBloc = _MockBidAcceptanceBloc();
    cancellationBloc = _MockCancellationBloc();
    trackingBloc = _MockTrackingBloc();
    conversationOpenBloc = _MockConversationOpenBloc();
    ratingBloc = _MockRatingBloc();
    paymentRepository = _MockPaymentRepository();

    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => Stream<BidState>.empty());
    when(() => cancellationBloc.state).thenReturn(CancellationInitial());
    when(
      () => cancellationBloc.stream,
    ).thenAnswer((_) => Stream<CancellationState>.empty());
    when(() => trackingBloc.state).thenReturn(TrackingInitial());
    when(
      () => trackingBloc.stream,
    ).thenAnswer((_) => Stream<TrackingState>.empty());
    when(
      () => conversationOpenBloc.state,
    ).thenReturn(const ConversationOpenInitial());
    when(
      () => conversationOpenBloc.stream,
    ).thenAnswer((_) => Stream<ConversationOpenState>.empty());
    when(() => ratingBloc.state).thenReturn(const RatingInitial());
    when(
      () => ratingBloc.stream,
    ).thenAnswer((_) => Stream<RatingState>.empty());
    when(() => acceptanceBloc.state).thenReturn(acs.BidAcceptanceInitial());
    when(
      () => acceptanceBloc.stream,
    ).thenAnswer((_) => Stream<acs.BidAcceptanceState>.empty());
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
  });

  tearDown(() {
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
  });

  // ── Task 4 : Badge CASH ──────────────────────────────────────────────────────

  group('Badge CASH', () {
    testWidgets('paymentMethod=cash → texte CASH visible', (tester) async {
      final authBloc = _MockAuthBloc();
      when(
        () => authBloc.state,
      ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
      when(() => authBloc.stream).thenAnswer((_) => Stream<AuthState>.empty());

      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: authBloc,
      );

      expect(find.text('CASH'), findsOneWidget);
    });

    testWidgets('paymentMethod=stripe → texte CASH absent', (tester) async {
      final authBloc = _MockAuthBloc();
      when(
        () => authBloc.state,
      ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
      when(() => authBloc.stream).thenAnswer((_) => Stream<AuthState>.empty());

      await _pump(
        tester,
        bid: _makeBid(
          paymentMethod: BidPaymentMethod.stripe,
          status: 'REJECTED',
        ),
        authBloc: authBloc,
      );

      expect(find.text('CASH'), findsNothing);
    });
  });

  // ── Task 4 : Bouton no-show voyageur ─────────────────────────────────────────

  group('Bouton no-show (voyageur, CASH, ACCEPTED, fenêtre passée)', () {
    testWidgets(
      'voyageur + cash + ACCEPTED + handoverWindowEnd passé → bouton visible',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            handoverWindowEnd: DateTime.now().subtract(
              const Duration(hours: 1),
            ),
          ),
          authBloc: authBloc,
        );

        expect(
          find.textContaining("L'expéditeur n'est pas venu"),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'voyageur + cash + ACCEPTED + handoverWindowEnd futur → bouton absent',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            handoverWindowEnd: DateTime.now().add(const Duration(hours: 2)),
          ),
          authBloc: authBloc,
        );

        expect(
          find.textContaining("L'expéditeur n'est pas venu"),
          findsNothing,
        );
      },
    );

    // Régression : le flux no-show est désormais bidirectionnel (CASH + Stripe).
    // Le voyageur peut signaler l'absence de l'expéditeur même en Stripe.
    testWidgets(
      'voyageur + STRIPE + ACCEPTED + handoverWindowEnd passé → bouton visible',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            paymentMethod: BidPaymentMethod.stripe,
            handoverWindowEnd: DateTime.now().subtract(
              const Duration(hours: 1),
            ),
          ),
          authBloc: authBloc,
        );

        expect(
          find.textContaining("L'expéditeur n'est pas venu"),
          findsOneWidget,
        );
      },
    );
  });

  // ── Task 12 : Bouton "Voyageur absent" (expéditeur signale le voyageur) ───────

  group('Section no-show voyageur (expéditeur, CASH + Stripe, ACCEPTED)', () {
    const kTitle = "Le voyageur ne s'est pas présenté ?";

    testWidgets(
      'expéditeur + ACCEPTED + handoverWindowEnd passé → section visible',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kSenderId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            paymentMethod: BidPaymentMethod.stripe,
            handoverWindowEnd: DateTime.now().subtract(
              const Duration(hours: 1),
            ),
          ),
          authBloc: authBloc,
        );

        // Le hero "Fenêtre de remise dépassée" porte le bouton de signalement.
        expect(
          find.textContaining("Signaler l'absence du voyageur"),
          findsOneWidget,
        );
        // Le titre n'apparaît que dans la bottom sheet (pas encore ouverte).
        expect(find.text(kTitle), findsNothing);
      },
    );

    testWidgets(
      'expéditeur + HANDED_OVER → section absente (disparaît à la remise)',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kSenderId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            status: 'HANDED_OVER',
            handoverWindowEnd: DateTime.now().subtract(
              const Duration(hours: 1),
            ),
          ),
          authBloc: authBloc,
        );

        expect(
          find.textContaining("Signaler l'absence du voyageur"),
          findsNothing,
        );
      },
    );

    testWidgets(
      'expéditeur + ACCEPTED + handoverWindowEnd futur → section absente',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kSenderId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            handoverWindowEnd: DateTime.now().add(const Duration(hours: 2)),
          ),
          authBloc: authBloc,
        );

        expect(
          find.textContaining("Signaler l'absence du voyageur"),
          findsNothing,
        );
      },
    );
  });

  // ── Task 5 : Bannière de contestation no-show ─────────────────────────────────

  group(
    'Bannière no-show contestation (expéditeur, CASH, PENDING_CONFIRMATION)',
    () {
      testWidgets(
        'expéditeur + cash + PENDING_CONFIRMATION → bannière avec boutons',
        (tester) async {
          final authBloc = _MockAuthBloc();
          when(
            () => authBloc.state,
          ).thenReturn(AuthAuthenticated(_user(_kSenderId)));
          when(
            () => authBloc.stream,
          ).thenAnswer((_) => Stream<AuthState>.empty());

          await _pump(
            tester,
            bid: _makeBid(
              status: 'REJECTED',
              cancellationNoShowStatus: 'PENDING_CONFIRMATION',
            ),
            authBloc: authBloc,
          );

          expect(
            find.textContaining('Absence signalée par le voyageur'),
            findsOneWidget,
          );
          expect(find.text('Je conteste'), findsOneWidget);
          expect(find.text('Je confirme'), findsOneWidget);
        },
      );

      testWidgets('voyageur + cash + PENDING_CONFIRMATION → bannière absente', (
        tester,
      ) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            status: 'REJECTED',
            cancellationNoShowStatus: 'PENDING_CONFIRMATION',
          ),
          authBloc: authBloc,
        );

        expect(
          find.textContaining('Absence signalée par le voyageur'),
          findsNothing,
        );
      });

      testWidgets(
        'expéditeur + cash + pas de cancellationNoShowStatus → bannière absente',
        (tester) async {
          final authBloc = _MockAuthBloc();
          when(
            () => authBloc.state,
          ).thenReturn(AuthAuthenticated(_user(_kSenderId)));
          when(
            () => authBloc.stream,
          ).thenAnswer((_) => Stream<AuthState>.empty());

          await _pump(
            tester,
            bid: _makeBid(status: 'REJECTED'),
            authBloc: authBloc,
          );

          expect(
            find.textContaining('Absence signalée par le voyageur'),
            findsNothing,
          );
        },
      );
    },
  );

  // ── Task 12 : Barres d'action voyageur ────────────────────────────────────────

  group("Barre d'action voyageur", () {
    testWidgets('voyageur + PENDING → Accepter / Refuser', (tester) async {
      final authBloc = _MockAuthBloc();
      when(
        () => authBloc.state,
      ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
      when(() => authBloc.stream).thenAnswer((_) => Stream<AuthState>.empty());
      await _pump(
        tester,
        bid: _makeBid(status: 'PENDING'),
        authBloc: authBloc,
      );
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });
  });

  // ── Task 7 : Intégration du billet de colis ───────────────────────────────────

  group('Billet de colis', () {
    testWidgets('ACCEPTED → ColisBillet affiché', (tester) async {
      final authBloc = _MockAuthBloc();
      when(
        () => authBloc.state,
      ).thenReturn(AuthAuthenticated(_user(_kSenderId)));
      when(() => authBloc.stream).thenAnswer((_) => Stream<AuthState>.empty());
      await _pump(
        tester,
        bid: _makeBid(status: 'ACCEPTED'),
        authBloc: authBloc,
      );
      expect(find.byType(ColisBillet), findsOneWidget);
    });
  });

  // ── Task 10 : ConfirmPresenceBar (fenêtre de remise depuis l'annonce) ──────────

  group('ConfirmPresenceBar (handoverWindowStart depuis annonce)', () {
    testWidgets(
      'voyageur + ACCEPTED + dans la fenêtre de remise → Confirmer ma présence visible',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        // Fenêtre qui commence dans 1 h (< 4 h → condition satisfaite) et
        // se termine dans 2 h (dans le futur → DateTime.now().isBefore()).
        final now = DateTime.now();
        final bid = BidModel(
          id: 'bid-window',
          announcementId: 'ann-window',
          senderId: _kSenderId,
          weightKg: 3,
          status: 'ACCEPTED',
          createdAt: now,
          updatedAt: now,
          paymentMethod: BidPaymentMethod.stripe,
          handoverWindowStart: now.add(const Duration(hours: 1)),
          handoverWindowEnd: now.add(const Duration(hours: 2)),
        );

        await _pump(tester, bid: bid, authBloc: authBloc);

        expect(find.text('Confirmer ma présence'), findsOneWidget);
      },
    );

    testWidgets(
      'voyageur + ACCEPTED + handoverWindowStart null → Confirmer ma présence absent',
      (tester) async {
        final authBloc = _MockAuthBloc();
        when(
          () => authBloc.state,
        ).thenReturn(AuthAuthenticated(_user(_kTravelerId)));
        when(
          () => authBloc.stream,
        ).thenAnswer((_) => Stream<AuthState>.empty());

        await _pump(
          tester,
          bid: _makeBid(
            paymentMethod: BidPaymentMethod.stripe,
            handoverWindowEnd: DateTime.now().add(const Duration(hours: 2)),
          ),
          authBloc: authBloc,
        );

        expect(find.text('Confirmer ma présence'), findsNothing);
      },
    );
  });
}
