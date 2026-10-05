import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
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
import 'package:dony/features/notifications/data/notification_service.dart';
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

class _MockNotificationService extends Mock implements NotificationService {}

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
}) => BidModel(
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
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/conversations/:id',
        builder: (_, _) => const Scaffold(body: Text('Conversation')),
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

  group('FLUTTER-CH — relecture du colis en attente du voyageur', () {
    for (final status in ['PENDING', 'PAYMENT_ESCROWED']) {
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

    testWidgets('push sur ce colis → relecture immédiate', (tester) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: senderAuth(),
      );
      expect(detailRequests(), 1);

      pushes.add({'type': 'BID_ACCEPTED', 'bidId': 'bid-001'});
      await tester.pump();
      expect(detailRequests(), 1);
    });

    testWidgets('push sur un autre colis → ignorée', (tester) async {
      await _pump(
        tester,
        bid: _makeBid(status: 'REJECTED'),
        authBloc: senderAuth(),
      );
      expect(detailRequests(), 1);

      pushes.add({'type': 'BID_ACCEPTED', 'bidId': 'bid-999'});
      pushes.add({'type': 'NEW_MESSAGE'});
      await tester.pump();
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
}
