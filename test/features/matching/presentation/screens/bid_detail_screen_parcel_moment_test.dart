import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/cancellation/bloc/delivery_noshow_procedure/delivery_noshow_procedure_cubit.dart';
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
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/mock_analytics_backend.dart';
import '../../../video_modal/moment_test_support.dart';

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

class _MockBidAcceptanceBloc
    extends MockBloc<BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockProcedureCubit extends MockCubit<DeliveryNoShowProcedureState>
    implements DeliveryNoShowProcedureCubit {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

class _MockNotificationService extends Mock implements NotificationService {}

const _kSenderId = 'sender-001';
const _kTravelerId = 'traveler-001';

BidModel _bid(String status, {bool recipientIsSender = false}) => BidModel(
  id: 'bid-001',
  announcementId: 'ann-001',
  senderId: _kSenderId,
  travelerId: _kTravelerId,
  senderName: 'Mariama',
  travelerName: 'Moussa',
  recipientName: 'Awa',
  recipientIsSender: recipientIsSender,
  confirmationCode: '482913',
  weightKg: 3,
  status: status,
  paymentMethod: BidPaymentMethod.cash,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  createdAt: DateTime(2026, 11),
  updatedAt: DateTime(2026, 11),
);

UserModel _user(String id) => UserModel(
  id: id,
  roles: const ['SENDER', 'TRAVELER'],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

/// Fiche colis : le moment d'étape part une fois par ouverture, au premier
/// chargement du colis, avec le rôle du lecteur ; jamais au rebuild ni au
/// relevé suivant de la même ouverture.
void main() {
  late _MockBidBloc bidBloc;
  late _MockAuthBloc authBloc;
  late StreamController<BidState> states;
  late RecordingMoments moments;

  setUpAll(() async {
    registerFallbackValue(BidDetailRequested('fallback'));
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('fr');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DonySnackbar.clearDedup();
    moments = useRecordingMoments();
    bidBloc = _MockBidBloc();
    authBloc = _MockAuthBloc();
    states = StreamController<BidState>.broadcast();
    final procedure = _MockProcedureCubit();
    final acceptanceBloc = _MockBidAcceptanceBloc();
    final cancellationBloc = _MockCancellationBloc();
    final trackingBloc = _MockTrackingBloc();
    final conversationOpenBloc = _MockConversationOpenBloc();
    final ratingBloc = _MockRatingBloc();
    final paymentRepository = _MockPaymentRepository();
    final notificationService = _MockNotificationService();

    when(() => bidBloc.state).thenReturn(BidInitial());
    when(() => bidBloc.stream).thenAnswer((_) => states.stream);
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
      () => authBloc.stream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
    when(
      () => paymentRepository.getPaymentForBid(any()),
    ).thenAnswer((_) async => null);
    when(
      () => notificationService.foregroundPushStream,
    ).thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
    whenListen(
      procedure,
      const Stream<DeliveryNoShowProcedureState>.empty(),
      initialState: const DeliveryNoShowProcedureUnavailable(),
    );
    when(() => procedure.load(any())).thenAnswer((_) async {});

    final analytics = makeEnabledAnalytics(MockAnalyticsBackend());
    await analytics.onConfigured();

    await getIt.reset();
    getIt
      ..registerFactory<BidBloc>(() => bidBloc)
      ..registerFactory<BidAcceptanceBloc>(() => acceptanceBloc)
      ..registerFactory<CancellationBloc>(() => cancellationBloc)
      ..registerFactory<TrackingBloc>(() => trackingBloc)
      ..registerFactory<ConversationOpenBloc>(() => conversationOpenBloc)
      ..registerFactory<RatingBloc>(() => ratingBloc)
      ..registerFactory<DeliveryNoShowProcedureCubit>(() => procedure)
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerLazySingleton<PaymentRepository>(() => paymentRepository)
      ..registerSingleton<NotificationService>(notificationService);
  });

  tearDown(() async {
    await states.close();
    await getIt.reset();
  });

  void viewer(String id) =>
      when(() => authBloc.state).thenReturn(AuthAuthenticated(_user(id)));

  Future<void> pumpScreen(WidgetTester tester, BidModel bid) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: BidDetailScreen(bid: bid),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> load(WidgetTester tester, BidModel bid) async {
    states.add(BidDetailLoaded(bid));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await flushStorage(tester);
  }

  testWidgets('expéditeur : une étape à la première lecture, avec le colis', (
    tester,
  ) async {
    viewer(_kSenderId);
    await pumpScreen(tester, _bid('ARRIVED'));
    // Pas encore chargé : rien.
    expect(moments.emitted, isEmpty);
    await load(tester, _bid('ARRIVED'));
    expect(moments.triggers, [VideoModalTrigger.parcelArrived]);
    final moment = moments.emitted.single;
    expect(moment.parcel!.bidId, 'bid-001');
    expect(moment.parcel!.roles, {ParcelRole.sender});
    expect(moment.variables['voyageur'], 'Moussa');
    expect(moment.variables.values.join(), isNot(contains('482913')));
    // Ouvert sur l'écran du colis.
    expect(moments.origins.single!.mounted, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('relevé suivant et rebuild de la même ouverture : rien de plus', (
    tester,
  ) async {
    viewer(_kSenderId);
    await pumpScreen(tester, _bid('IN_TRANSIT'));
    await load(tester, _bid('IN_TRANSIT'));
    await load(tester, _bid('IN_TRANSIT'));
    // Le statut change sous les yeux : toujours la même ouverture.
    await load(tester, _bid('ARRIVED'));
    await tester.pump(const Duration(seconds: 1));
    expect(moments.triggers, [VideoModalTrigger.parcelInTransit]);
  });

  testWidgets('fiche rouverte plus tard : une nouvelle ouverture', (
    tester,
  ) async {
    viewer(_kSenderId);
    await pumpScreen(tester, _bid('ARRIVED'));
    await load(tester, _bid('ARRIVED'));
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, _bid('ARRIVED'));
    await load(tester, _bid('ARRIVED'));
    expect(moments.triggers, [
      VideoModalTrigger.parcelArrived,
      VideoModalTrigger.parcelArrived,
    ]);
  });

  testWidgets('voyageur : son rôle', (tester) async {
    viewer(_kTravelerId);
    await pumpScreen(tester, _bid('ACCEPTED'));
    await load(tester, _bid('ACCEPTED'));
    expect(moments.triggers, [VideoModalTrigger.parcelAccepted]);
    expect(moments.emitted.single.parcel!.roles, {ParcelRole.traveler});
  });

  testWidgets('expéditeur qui est son propre destinataire : les deux rôles', (
    tester,
  ) async {
    viewer(_kSenderId);
    final bid = _bid('HANDED_OVER', recipientIsSender: true);
    await pumpScreen(tester, bid);
    await load(tester, bid);
    expect(moments.emitted.single.parcel!.roles, {
      ParcelRole.sender,
      ParcelRole.recipient,
    });
  });

  testWidgets('colis livré : PARCEL_DELIVERED', (tester) async {
    viewer(_kSenderId);
    await pumpScreen(tester, _bid('COMPLETED'));
    await load(tester, _bid('COMPLETED'));
    expect(moments.triggers, [VideoModalTrigger.parcelDelivered]);
  });

  testWidgets('outOfRailsStatus_emitsNoMoment, même si le statut avance', (
    tester,
  ) async {
    viewer(_kSenderId);
    await pumpScreen(tester, _bid('PENDING'));
    await load(tester, _bid('PENDING'));
    await load(tester, _bid('ACCEPTED'));
    expect(moments.emitted, isEmpty);
  });

  testWidgets('lecteur ni expéditeur ni voyageur : aucun moment', (
    tester,
  ) async {
    viewer('quelqu-un-d-autre');
    await pumpScreen(tester, _bid('ARRIVED'));
    await load(tester, _bid('ARRIVED'));
    expect(moments.emitted, isEmpty);
  });
}
