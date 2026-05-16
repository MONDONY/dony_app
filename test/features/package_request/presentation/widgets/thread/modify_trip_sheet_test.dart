import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/data/models/address_data.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/modify_trip_sheet.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_bloc.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_event.dart';
import 'package:dony/features/payments/cash/bloc/commission_method_state.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockCommissionMethodBloc
    extends MockBloc<CommissionMethodEvent, CommissionMethodState>
    implements CommissionMethodBloc {}

const _validCard = CommissionMethod(
  brand: 'visa',
  last4: '4242',
  expMonth: 12,
  expYear: 2030,
  expirationStatus: ExpirationStatus.valid,
);
const _expiredCard = CommissionMethod(
  brand: 'visa',
  last4: '1234',
  expMonth: 1,
  expYear: 2020,
  expirationStatus: ExpirationStatus.expired,
);

AnnouncementModel _trip({
  double availableKg = 10,
  int? bidsCount,
  Set<BidPaymentMethod> payments = const {BidPaymentMethod.stripe},
  AddressData? pickup,
  AddressData? delivery,
}) {
  return AnnouncementModel(
    id: 'ann-1',
    travelerId: 'trav-1',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureDate: DateTime(2026, 8, 15),
    availableKg: availableKg,
    totalKg: 23,
    pricePerKg: 7,
    status: 'ACTIVE',
    transportMode: TransportMode.plane,
    pickupAddress:
        pickup ?? const AddressData(label: '10 rue de Rivoli, Paris', lat: 48.86, lng: 2.35),
    deliveryAddress:
        delivery ?? const AddressData(label: 'Aéroport de Dakar', lat: 14.74, lng: -17.49),
    bidsCount: bidsCount,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    acceptedPaymentMethods: payments,
  );
}

late MockAnnouncementBloc announcementBloc;
late MockCommissionMethodBloc commissionBloc;

Widget _harness(AnnouncementModel trip) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open'),
              onPressed: () => ModifyTripSheet.show(ctx, announcement: trip),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/payments/commission-method',
        builder: (ctx, _) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('retour-stub'),
              onPressed: () => ctx.pop(),
              child: const Text('Commission stub'),
            ),
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
}

Future<void> _open(WidgetTester tester, AnnouncementModel trip) async {
  await tester.pumpWidget(_harness(trip));
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(CommissionMethodLoadRequested());
    registerFallbackValue(AnnouncementUpdateRequested(
      id: '',
      departureCity: '',
      arrivalCity: '',
      departureDate: DateTime(2026),
      pickupAddress: const AddressData(label: '', lat: 0, lng: 0),
      deliveryAddress: const AddressData(label: '', lat: 0, lng: 0),
      availableKg: 0,
      pricePerKg: 0,
      transportMode: TransportMode.plane,
    ));
  });

  setUp(() {
    announcementBloc = MockAnnouncementBloc();
    when(() => announcementBloc.state).thenReturn(AnnouncementInitial());
    when(() => announcementBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    commissionBloc = MockCommissionMethodBloc();
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodNotConfigured());
    when(() => commissionBloc.stream)
        .thenAnswer((_) => const Stream.empty());

    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
    getIt.registerFactory<AnnouncementBloc>(() => announcementBloc);
    getIt.registerFactory<CommissionMethodBloc>(() => commissionBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<AnnouncementBloc>()) {
      getIt.unregister<AnnouncementBloc>();
    }
    if (getIt.isRegistered<CommissionMethodBloc>()) {
      getIt.unregister<CommissionMethodBloc>();
    }
  });

  testWidgets('affiche le titre et le bloc verrouillé en lecture seule',
      (tester) async {
    await _open(tester, _trip());
    expect(find.text('Modifier le trajet'), findsOneWidget);
    expect(find.text('NON MODIFIABLE'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.text('10 rue de Rivoli, Paris'), findsOneWidget);
  });

  testWidgets('affiche la bannière quand le trajet a déjà des offres',
      (tester) async {
    await _open(tester, _trip(bidsCount: 2));
    expect(find.byKey(const Key('modify-trip-offers-warning')),
        findsOneWidget);
  });

  testWidgets('masque la bannière quand bidsCount vaut 0', (tester) async {
    await _open(tester, _trip(bidsCount: 0));
    expect(find.byKey(const Key('modify-trip-offers-warning')), findsNothing);
  });

  testWidgets('le stepper incrémente et décrémente la capacité',
      (tester) async {
    await _open(tester, _trip());
    expect(find.text('10 kg'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('capacity-increment')));
    await tester.tap(find.byKey(const Key('capacity-increment')));
    await tester.pump();
    expect(find.text('11 kg'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('capacity-decrement')));
    await tester.tap(find.byKey(const Key('capacity-decrement')));
    await tester.pump();
    expect(find.text('10 kg'), findsOneWidget);
  });

  testWidgets('le stepper est borné à 1 kg minimum', (tester) async {
    await _open(tester, _trip(availableKg: 1));
    await tester.ensureVisible(find.byKey(const Key('capacity-decrement')));
    await tester.tap(find.byKey(const Key('capacity-decrement')));
    await tester.pump();
    expect(find.text('1 kg'), findsOneWidget);
  });

  testWidgets('le stepper est borné à 23 kg maximum', (tester) async {
    await _open(tester, _trip(availableKg: 23));
    await tester.ensureVisible(find.byKey(const Key('capacity-increment')));
    await tester.tap(find.byKey(const Key('capacity-increment')));
    await tester.pump();
    expect(find.text('23 kg'), findsOneWidget);
  });

  testWidgets('le toggle liquide est ON quand l\'annonce accepte le cash',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_validCard));
    await _open(tester, _trip(
      payments: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
    ));
    await tester.ensureVisible(
        find.byKey(const Key('modify-trip-cash-switch')));
    final sw = tester.widget<Switch>(
        find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isTrue);
  });

  testWidgets('le toggle liquide est OFF par défaut', (tester) async {
    await _open(tester, _trip());
    await tester.ensureVisible(
        find.byKey(const Key('modify-trip-cash-switch')));
    final sw = tester.widget<Switch>(
        find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isFalse);
  });

  testWidgets('activer le liquide avec une carte valide passe le toggle ON',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_validCard));
    await _open(tester, _trip());
    await tester.ensureVisible(
        find.byKey(const Key('modify-trip-cash-switch')));
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pump();
    final sw = tester.widget<Switch>(
        find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isTrue);
  });

  testWidgets('activer le liquide sans carte ouvre la configuration',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodNotConfigured());
    await _open(tester, _trip());
    await tester.ensureVisible(
        find.byKey(const Key('modify-trip-cash-switch')));
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retour-stub')), findsOneWidget);
  });

  testWidgets('activer le liquide avec une carte expirée ouvre la config',
      (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_expiredCard));
    await _open(tester, _trip());
    await tester.ensureVisible(
        find.byKey(const Key('modify-trip-cash-switch')));
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retour-stub')), findsOneWidget);
  });

  testWidgets('désactiver le liquide repasse le toggle OFF', (tester) async {
    when(() => commissionBloc.state)
        .thenReturn(CommissionMethodLoaded(_validCard));
    await _open(tester, _trip(
      payments: const {BidPaymentMethod.stripe, BidPaymentMethod.cash},
    ));
    var sw = tester
        .widget<Switch>(find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isTrue);
    await tester
        .ensureVisible(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pump();
    sw = tester
        .widget<Switch>(find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isFalse);
  });

  testWidgets(
      'annuler le détour ne réactive pas le liquide sur un état ultérieur',
      (tester) async {
    final controller =
        StreamController<CommissionMethodState>.broadcast();
    addTearDown(controller.close);
    whenListen(commissionBloc, controller.stream,
        initialState: CommissionMethodNotConfigured());
    await _open(tester, _trip());

    await tester
        .ensureVisible(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.tap(find.byKey(const Key('modify-trip-cash-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retour-stub')), findsOneWidget);

    // Retour du détour SANS configurer de carte.
    await tester.tap(find.byKey(const Key('retour-stub')));
    await tester.pumpAndSettle();
    controller.add(CommissionMethodNotConfigured());
    await tester.pumpAndSettle();

    // Un état carte-valide arrive plus tard (source non liée).
    controller.add(CommissionMethodLoaded(_validCard));
    await tester.pumpAndSettle();

    final sw = tester
        .widget<Switch>(find.byKey(const Key('modify-trip-cash-switch')));
    expect(sw.value, isFalse);
  });
}
