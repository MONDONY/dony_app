import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/content_category.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:dony/features/package_request/presentation/screens/traveler/link_trip_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockPackageRequestRepository extends Mock
    implements PackageRequestRepository {}

class _MockAnnouncementRepository extends Mock
    implements AnnouncementRepository {}

// ── Helpers ──────────────────────────────────────────────────────────────────

PackageRequest _packageRequest({
  Set<PaymentMethod> methods = const {PaymentMethod.stripe, PaymentMethod.cash},
}) => PackageRequest(
  id: 'pr-1',
  senderId: 'sender-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  desiredDate: DateTime(2026, 8, 15),
  dateToleranceDays: 3,
  weightKg: 5,
  parcelSize: ParcelSize.medium,
  transportMode: TransportMode.plane,
  categories: const ['Autre'],
  status: PackageRequestStatus.negotiating,
  createdAt: DateTime(2026, 1, 1),
  acceptedPaymentMethods: methods,
);

NegotiationThread _fakeThread({
  NegotiationThreadStatus status = NegotiationThreadStatus.awaitingTrip,
}) => NegotiationThread(
  id: 't-1',
  packageRequestId: 'pr-1',
  travelerId: 'tr-1',
  travelerTravelDate: DateTime(2026, 8, 15),
  travelerAvailableKg: 10,
  status: status,
  currentPriceEur: 35,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 5, 10),
  createdAt: DateTime(2026, 5, 10),
  messages: const [],
);

typedef _MyTripsResult = ({
  List<AnnouncementModel> announcements,
  int totalElements,
});

_MyTripsResult _emptyTrips() =>
    (announcements: const <AnnouncementModel>[], totalElements: 0);

late _MockNegotiationBloc negotiationBloc;
late _MockPackageRequestRepository packageRequestRepo;
late _MockAnnouncementRepository announcementRepo;

Widget _harness(NegotiationThread thread) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => BlocProvider<NegotiationBloc>.value(
          value: negotiationBloc,
          child: LinkTripScreen(thread: thread),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

Future<void> _pump(
  WidgetTester tester, {
  NegotiationThread? thread,
  PackageRequest? request,
  Set<PaymentMethod> methods = const {PaymentMethod.stripe, PaymentMethod.cash},
}) async {
  final t = thread ?? _fakeThread();
  final req = request ?? _packageRequest(methods: methods);
  when(() => packageRequestRepo.getById(any())).thenAnswer((_) async => req);
  when(
    () => announcementRepo.getMyAnnouncements(),
  ).thenAnswer((_) async => _emptyTrips());

  await tester.pumpWidget(_harness(t));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(
      const NegotiationSubmitTripRequested(
        threadId: '',
        travelerAnnouncementId: '',
        paymentMethod: PaymentMethod.stripe,
      ),
    );
  });

  setUp(() {
    negotiationBloc = _MockNegotiationBloc();
    when(() => negotiationBloc.state).thenReturn(const NegotiationInitial());
    when(() => negotiationBloc.stream).thenAnswer((_) => const Stream.empty());

    packageRequestRepo = _MockPackageRequestRepository();
    announcementRepo = _MockAnnouncementRepository();

    if (getIt.isRegistered<PackageRequestRepository>()) {
      getIt.unregister<PackageRequestRepository>();
    }
    if (getIt.isRegistered<AnnouncementRepository>()) {
      getIt.unregister<AnnouncementRepository>();
    }
    getIt.registerFactory<PackageRequestRepository>(() => packageRequestRepo);
    getIt.registerFactory<AnnouncementRepository>(() => announcementRepo);
  });

  tearDown(() {
    if (getIt.isRegistered<PackageRequestRepository>()) {
      getIt.unregister<PackageRequestRepository>();
    }
    if (getIt.isRegistered<AnnouncementRepository>()) {
      getIt.unregister<AnnouncementRepository>();
    }
  });

  // ── Test 1: Payment method chips are shown ──────────────────────────────

  testWidgets('affiche les chips des méthodes de paiement acceptées', (
    tester,
  ) async {
    await _pump(tester, methods: {PaymentMethod.stripe, PaymentMethod.cash});

    expect(find.byKey(const Key('payment-method-stripe')), findsOneWidget);
    expect(find.byKey(const Key('payment-method-cash')), findsOneWidget);
  });

  testWidgets('affiche uniquement stripe si seule méthode acceptée', (
    tester,
  ) async {
    await _pump(tester, methods: {PaymentMethod.stripe});

    expect(find.byKey(const Key('payment-method-stripe')), findsOneWidget);
    expect(find.byKey(const Key('payment-method-cash')), findsNothing);
  });

  // ── Test 2: Selected payment method is passed on submit ──────────────────

  testWidgets(
    'passer en cash puis confirmer dispatch l\'événement avec paymentMethod cash',
    (tester) async {
      when(() => negotiationBloc.add(any())).thenReturn(null);

      // Add a matching trip so there's something to select
      final trip = AnnouncementModel(
        id: 'ann-1',
        travelerId: 'trav-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 8, 15),
        availableKg: 10,
        totalKg: 23,
        pricePerKg: 7,
        status: 'ACTIVE',
        transportMode: TransportMode.plane,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        acceptedPaymentMethods: const {
          BidPaymentMethod.stripe,
          BidPaymentMethod.cash,
        },
      );
      when(
        () => packageRequestRepo.getById(any()),
      ).thenAnswer((_) async => _packageRequest());
      when(
        () => announcementRepo.getMyAnnouncements(),
      ).thenAnswer((_) async => (announcements: [trip], totalElements: 1));

      await tester.pumpWidget(_harness(_fakeThread()));
      await tester.pumpAndSettle();

      // Select the cash payment method chip
      await tester.ensureVisible(find.byKey(const Key('payment-method-cash')));
      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();

      // Select the trip by tapping the selection InkWell
      expect(find.byKey(const Key('trip-tile-select-inkwell')), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
      await tester.pumpAndSettle();

      // After selecting a trip, the confirm button becomes active
      expect(find.text('Confirmer ce trajet'), findsOneWidget);
      await tester.tap(find.text('Confirmer ce trajet'));
      await tester.pump();

      verify(
        () => negotiationBloc.add(
          any(
            that: predicate<NegotiationEvent>(
              (e) =>
                  e is NegotiationSubmitTripRequested &&
                  e.threadId == 't-1' &&
                  e.travelerAnnouncementId == 'ann-1' &&
                  e.paymentMethod == PaymentMethod.cash,
              'NegotiationSubmitTripRequested avec paymentMethod=cash',
            ),
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('stripe est sélectionné par défaut', (tester) async {
    when(() => negotiationBloc.add(any())).thenReturn(null);

    final trip = AnnouncementModel(
      id: 'ann-2',
      travelerId: 'trav-1',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 8, 15),
      availableKg: 10,
      totalKg: 23,
      pricePerKg: 7,
      status: 'ACTIVE',
      transportMode: TransportMode.plane,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      acceptedPaymentMethods: const {
        BidPaymentMethod.stripe,
        BidPaymentMethod.cash,
      },
    );
    when(
      () => packageRequestRepo.getById(any()),
    ).thenAnswer((_) async => _packageRequest());
    when(
      () => announcementRepo.getMyAnnouncements(),
    ).thenAnswer((_) async => (announcements: [trip], totalElements: 1));

    await tester.pumpWidget(_harness(_fakeThread()));
    await tester.pumpAndSettle();

    // Select the trip by tapping the selection InkWell
    expect(find.byKey(const Key('trip-tile-select-inkwell')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
    await tester.pumpAndSettle();

    // Tap confirm without changing payment method
    expect(find.text('Confirmer ce trajet'), findsOneWidget);
    await tester.tap(find.text('Confirmer ce trajet'));
    await tester.pump();

    // Should dispatch with stripe (default)
    verify(
      () => negotiationBloc.add(
        any(
          that: predicate<NegotiationEvent>(
            (e) =>
                e is NegotiationSubmitTripRequested &&
                e.paymentMethod == PaymentMethod.stripe,
            'NegotiationSubmitTripRequested avec paymentMethod=stripe par défaut',
          ),
        ),
      ),
    ).called(1);
  });

  // ── Test 3: Cash insufficient funds error ─────────────────────────────────

  testWidgets(
    'erreur cash insuffisant → bottom sheet « Solde insuffisant » (recharge / carte)',
    (tester) async {
      final controller = StreamController<NegotiationState>.broadcast();
      addTearDown(controller.close);
      whenListen(
        negotiationBloc,
        controller.stream,
        initialState: const NegotiationInitial(),
      );
      when(() => negotiationBloc.add(any())).thenReturn(null);

      // A matching trip so the traveler can select one before the error fires.
      final trip = AnnouncementModel(
        id: 'ann-1',
        travelerId: 'trav-1',
        departureCity: 'Paris',
        arrivalCity: 'Dakar',
        departureDate: DateTime(2026, 8, 15),
        availableKg: 10,
        totalKg: 23,
        pricePerKg: 7,
        status: 'ACTIVE',
        transportMode: TransportMode.plane,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        acceptedPaymentMethods: const {
          BidPaymentMethod.stripe,
          BidPaymentMethod.cash,
        },
      );
      when(
        () => packageRequestRepo.getById(any()),
      ).thenAnswer((_) async => _packageRequest());
      when(
        () => announcementRepo.getMyAnnouncements(),
      ).thenAnswer((_) async => (announcements: [trip], totalElements: 1));

      await tester.pumpWidget(_harness(_fakeThread()));
      await tester.pumpAndSettle();

      // Select cash + the trip, then confirm (a trip must be selected for the sheet).
      await tester.ensureVisible(find.byKey(const Key('payment-method-cash')));
      await tester.tap(find.byKey(const Key('payment-method-cash')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer ce trajet'));
      await tester.pump();

      // Backend rejects: wallet too short for the cash commission.
      controller.add(
        NegotiationError(
          const ValidationException(
            'Insufficient funds for cash payment',
            code: 'payment-method/traveler-insufficient-funds-cash',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Wallet-first sheet (recharge OR card), not a dead-end snackbar.
      expect(find.text('Solde insuffisant'), findsOneWidget);
      expect(find.text('Recharger mon wallet'), findsOneWidget);
    },
  );
}
