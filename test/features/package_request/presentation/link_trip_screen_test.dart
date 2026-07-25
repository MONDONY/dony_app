import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/announcement_repository.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
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
  Set<PaymentMethod>? availablePaymentMethods,
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
  availablePaymentMethods: availablePaymentMethods,
);

AnnouncementModel _trip({String id = 'ann-1'}) => AnnouncementModel(
  id: id,
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
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
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
    when(() => negotiationBloc.add(any())).thenReturn(null);

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

  // ── PaymentCapabilityBlock.fromErrorCode — reason → UX mapping (pure) ────

  group('PaymentCapabilityBlock.fromErrorCode', () {
    test('mappe card-capability-required', () {
      expect(
        PaymentCapabilityBlock.fromErrorCode(
          'payment-method/card-capability-required',
        ),
        PaymentCapabilityBlock.cardCapabilityRequired,
      );
    });

    test('mappe cash-funds-required', () {
      expect(
        PaymentCapabilityBlock.fromErrorCode('payment-method/cash-funds-required'),
        PaymentCapabilityBlock.cashFundsRequired,
      );
    });

    test('mappe none-available', () {
      expect(
        PaymentCapabilityBlock.fromErrorCode('payment-method/none-available'),
        PaymentCapabilityBlock.noneAvailable,
      );
    });

    test('retourne null pour les anciennes reasons cash-gate retirées', () {
      expect(
        PaymentCapabilityBlock.fromErrorCode(
          'payment-method/traveler-insufficient-funds-cash',
        ),
        isNull,
      );
      expect(
        PaymentCapabilityBlock.fromErrorCode('payment-method/no-commission-card'),
        isNull,
      );
    });

    test('retourne null pour un code inconnu ou absent', () {
      expect(PaymentCapabilityBlock.fromErrorCode('some/other-code'), isNull);
      expect(PaymentCapabilityBlock.fromErrorCode(null), isNull);
    });
  });

  // ── Aperçu lecture seule des modes de paiement ────────────────────────────

  group('LinkTripScreen — aperçu lecture seule', () {
    testWidgets(
      'avant soumission, affiche les méthodes acceptées par la demande',
      (tester) async {
        when(
          () => packageRequestRepo.getById(any()),
        ).thenAnswer(
          (_) async =>
              _packageRequest(methods: {PaymentMethod.stripe, PaymentMethod.cash}),
        );
        when(
          () => announcementRepo.getMyAnnouncements(),
        ).thenAnswer((_) async => _emptyTrips());

        await tester.pumpWidget(_harness(_fakeThread()));
        await tester.pumpAndSettle();

        expect(find.text('L\'expéditeur choisira parmi'), findsOneWidget);
        expect(
          find.byKey(const Key('payment-method-preview-stripe')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('payment-method-preview-cash')),
          findsOneWidget,
        );
        // Read-only: no more selectable chips from the old picker.
        expect(find.byKey(const Key('payment-method-stripe')), findsNothing);
      },
    );

    testWidgets(
      'une fois le trajet lié, préfère la SET calculée côté serveur '
      '(thread.availablePaymentMethods)',
      (tester) async {
        when(
          () => packageRequestRepo.getById(any()),
        ).thenAnswer(
          (_) async =>
              _packageRequest(methods: {PaymentMethod.stripe, PaymentMethod.cash}),
        );
        when(
          () => announcementRepo.getMyAnnouncements(),
        ).thenAnswer((_) async => _emptyTrips());

        await tester.pumpWidget(
          _harness(_fakeThread(availablePaymentMethods: {PaymentMethod.cash})),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('payment-method-preview-cash')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('payment-method-preview-stripe')),
          findsNothing,
        );
      },
    );
  });

  // ── Confirmation : paiement décidé par le back-end, pas par le voyageur ──

  testWidgets(
    'confirmer un trajet dispatch paymentMethod=premier accepté et '
    'useCardForCommission=false (le back-end ignore paymentMethod)',
    (tester) async {
      when(
        () => packageRequestRepo.getById(any()),
      ).thenAnswer(
        (_) async =>
            _packageRequest(methods: {PaymentMethod.cash, PaymentMethod.stripe}),
      );
      when(
        () => announcementRepo.getMyAnnouncements(),
      ).thenAnswer((_) async => (announcements: [_trip()], totalElements: 1));

      await tester.pumpWidget(_harness(_fakeThread()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('trip-tile-select-inkwell')), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
      await tester.pumpAndSettle();

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
                  e.paymentMethod == PaymentMethod.cash &&
                  e.useCardForCommission == false,
              'NegotiationSubmitTripRequested(paymentMethod=cash, '
              'useCardForCommission=false)',
            ),
          ),
        ),
      ).called(1);
    },
  );

  // ── 422 reason → CTA contextuel ───────────────────────────────────────────

  group('LinkTripScreen — 422 reason routing', () {
    Future<void> pumpWithTripSelected(WidgetTester tester) async {
      when(
        () => packageRequestRepo.getById(any()),
      ).thenAnswer((_) async => _packageRequest());
      when(
        () => announcementRepo.getMyAnnouncements(),
      ).thenAnswer((_) async => (announcements: [_trip()], totalElements: 1));

      await tester.pumpWidget(_harness(_fakeThread()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-tile-select-inkwell')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'card-capability-required → sheet « Activer le paiement carte »',
      (tester) async {
        final controller = StreamController<NegotiationState>.broadcast();
        addTearDown(controller.close);
        whenListen(
          negotiationBloc,
          controller.stream,
          initialState: const NegotiationInitial(),
        );

        await pumpWithTripSelected(tester);
        await tester.tap(find.text('Confirmer ce trajet'));
        await tester.pump();

        controller.add(
          const NegotiationError(
            ValidationException(
              'Card capability required',
              code: 'payment-method/card-capability-required',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Paiement carte requis'), findsOneWidget);
        expect(find.byKey(const Key('activate-card-payment-cta')), findsOneWidget);
        expect(find.text('Activer le paiement carte'), findsOneWidget);
      },
    );

    testWidgets(
      'cash-funds-required → sheet « Solde insuffisant » (recharge / carte)',
      (tester) async {
        final controller = StreamController<NegotiationState>.broadcast();
        addTearDown(controller.close);
        whenListen(
          negotiationBloc,
          controller.stream,
          initialState: const NegotiationInitial(),
        );

        await pumpWithTripSelected(tester);
        await tester.tap(find.text('Confirmer ce trajet'));
        await tester.pump();

        controller.add(
          const NegotiationError(
            ValidationException(
              'Cash funds required',
              code: 'payment-method/cash-funds-required',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Solde insuffisant'), findsOneWidget);
        expect(find.text('Recharger mon portefeuille'), findsOneWidget);
        expect(find.textContaining('commission'), findsWidgets);
      },
    );

    testWidgets(
      'none-available → sheet combinée offrant carte ET espèces',
      (tester) async {
        final controller = StreamController<NegotiationState>.broadcast();
        addTearDown(controller.close);
        whenListen(
          negotiationBloc,
          controller.stream,
          initialState: const NegotiationInitial(),
        );

        await pumpWithTripSelected(tester);
        await tester.tap(find.text('Confirmer ce trajet'));
        await tester.pump();

        controller.add(
          const NegotiationError(
            ValidationException(
              'No payment method available',
              code: 'payment-method/none-available',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Aucun moyen de paiement disponible'), findsOneWidget);
        expect(find.byKey(const Key('activate-card-payment-cta')), findsOneWidget);
        expect(find.byKey(const Key('unlock-cash-payment-cta')), findsOneWidget);
      },
    );

    testWidgets(
      'reason inconnue → snackbar générique (pas de sheet)',
      (tester) async {
        final controller = StreamController<NegotiationState>.broadcast();
        addTearDown(controller.close);
        whenListen(
          negotiationBloc,
          controller.stream,
          initialState: const NegotiationInitial(),
        );

        await pumpWithTripSelected(tester);
        await tester.tap(find.text('Confirmer ce trajet'));
        await tester.pump();

        controller.add(
          const NegotiationError(
            ValidationException(
              'Some unrelated business error',
              code: 'some/other-code',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Paiement carte requis'), findsNothing);
        expect(find.text('Solde insuffisant'), findsNothing);
        expect(find.text('Aucun moyen de paiement disponible'), findsNothing);
        expect(find.text('Some unrelated business error'), findsOneWidget);
      },
    );
  });
}
