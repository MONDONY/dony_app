import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockPaymentBloc extends MockBloc<PaymentEvent, PaymentState>
    implements PaymentBloc {}

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid(String status, String arrivee, {DateTime? departureDate}) =>
    BidModel(
      id: 'b_$arrivee',
      announcementId: 'a1',
      senderId: 's1',
      status: status,
      departureCity: 'Paris',
      arrivalCity: arrivee,
      departureDate: departureDate,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
      paymentMethod: BidPaymentMethod.stripe,
      pricingMode: BidPricingMode.kg,
    );

void main() {
  late _MockBidBloc bidBloc;
  late _MockPaymentBloc paymentBloc;
  late _MockAnalytics analytics;

  setUpAll(() async => initializeDateFormatting('fr'));
  setUp(() {
    bidBloc = _MockBidBloc();
    paymentBloc = _MockPaymentBloc();
    whenListen<PaymentState>(
      paymentBloc,
      const Stream<PaymentState>.empty(),
      initialState: PaymentInitial(),
    );
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<ShipmentFilterCubit>()) {
      getIt.unregister<ShipmentFilterCubit>();
    }
    getIt.registerFactory(() => ShipmentFilterCubit(analytics));
    if (!getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.registerLazySingleton(() => EnvoisRefreshNotifier());
    }
  });

  tearDown(() {
    if (getIt.isRegistered<ShipmentFilterCubit>()) {
      getIt.unregister<ShipmentFilterCubit>();
    }
    if (getIt.isRegistered<EnvoisRefreshNotifier>()) {
      getIt.unregister<EnvoisRefreshNotifier>();
    }
  });

  Widget subject() => MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<BidBloc>.value(value: bidBloc),
        BlocProvider<PaymentBloc>.value(value: paymentBloc),
      ],
      child: const ShipmentListBody(),
    ),
  );

  testWidgets('puce rapide « Passés » ne montre que les livrés/clôturés', (
    tester,
  ) async {
    final bids = [_bid('ACCEPTED', 'Dakar'), _bid('COMPLETED', 'Abidjan')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Passés'));
    await tester.pumpAndSettle();

    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsNothing);
  });

  testWidgets('recherche filtre la liste après debounce', (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar'), _bid('ACCEPTED', 'Bamako')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'bamako');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Paris → Bamako'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsNothing);
  });

  testWidgets('état vide filtré affiche Réinitialiser', (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucun envoi ne correspond'), findsOneWidget);
    expect(find.text('Réinitialiser'), findsOneWidget);
  });

  testWidgets('mode standalone (embedded:false) affiche le header sombre « Mes envois »',
      (tester) async {
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(const [])]),
      initialState: BidListLoaded(const []),
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<PaymentBloc>.value(value: paymentBloc),
            ],
            child: const ShipmentListScreen(embedded: false),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Mes envois'), findsOneWidget);
  });

  testWidgets('état BidLoading affiche un spinner', (tester) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidLoading(),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('état BidInitial affiche un spinner', (tester) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidInitial(),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('état BidError affiche un message d\'erreur', (tester) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidError(const NetworkException('Erreur réseau')),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Erreur de chargement'), findsOneWidget);
  });

  testWidgets('liste vide totale affiche « Aucun envoi »', (tester) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(const []),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Aucun envoi'), findsOneWidget);
  });

  testWidgets('puce rapide « En cours » filtre les bids ACCEPTED/HANDED_OVER/IN_TRANSIT',
      (tester) async {
    final bids = [
      _bid('ACCEPTED', 'Dakar'),
      _bid('PENDING', 'Abidjan'),
    ];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();

    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsNothing);
  });

  testWidgets('puce rapide « Tous » réinitialise le filtre statut', (tester) async {
    final bids = [
      _bid('ACCEPTED', 'Dakar'),
      _bid('PENDING', 'Abidjan'),
    ];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    // Filter first
    await tester.tap(find.text('En cours'));
    await tester.pumpAndSettle();
    // Reset
    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();

    expect(find.text('Paris → Dakar'), findsOneWidget);
    expect(find.text('Paris → Abidjan'), findsOneWidget);
  });

  testWidgets('puce rapide « À venir » filtre PENDING/AWAITING_PAYMENT/PAYMENT_ESCROWED',
      (tester) async {
    final bids = [
      _bid('ACCEPTED', 'Dakar'),
      _bid('AWAITING_PAYMENT', 'Abidjan'),
    ];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('À venir'));
    await tester.pumpAndSettle();

    expect(find.text('Paris → Abidjan'), findsOneWidget);
    expect(find.text('Paris → Dakar'), findsNothing);
  });

  testWidgets('« Tout effacer » réinitialise les filtres actifs', (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    // Activate a filter (search)
    await tester.enterText(find.byType(TextField).first, 'dakar');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // "Tout effacer" should appear and reset
    expect(find.text('Tout effacer'), findsOneWidget);
    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();

    // Filter is cleared, "Tout effacer" no longer visible
    expect(find.text('Tout effacer'), findsNothing);
  });

  testWidgets('BidListLoaded avec isRefreshing = true affiche le LinearProgressIndicator',
      (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(bids, isRefreshing: true),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('carte AWAITING_PAYMENT affiche le bouton « Payer → »', (tester) async {
    final bids = [_bid('AWAITING_PAYMENT', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Payer →'), findsOneWidget);
  });

  testWidgets('carte COMPLETED affiche le badge LIVRÉ et le CTA « Détail → »',
      (tester) async {
    final bids = [_bid('COMPLETED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('LIVRÉ'), findsOneWidget);
    expect(find.text('Détail →'), findsOneWidget);
  });

  testWidgets('carte ACCEPTED affiche le badge CONFIRMÉ et le CTA « Voir → »',
      (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('CONFIRMÉ'), findsOneWidget);
    expect(find.text('Voir →'), findsOneWidget);
  });

  testWidgets('carte REJECTED affiche badge REFUSÉ et CTA désactivé', (tester) async {
    final bids = [_bid('REJECTED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('REFUSÉ'), findsOneWidget);
  });

  testWidgets('carte CANCELLED affiche badge ANNULÉ', (tester) async {
    final bids = [_bid('CANCELLED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('ANNULÉ'), findsOneWidget);
  });

  testWidgets('carte IN_TRANSIT affiche badge EN TRANSIT', (tester) async {
    final bids = [_bid('IN_TRANSIT', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('EN TRANSIT'), findsOneWidget);
  });

  testWidgets('carte NO_SHOW affiche badge ABSENT', (tester) async {
    final bids = [_bid('NO_SHOW', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('ABSENT'), findsOneWidget);
  });

  testWidgets('carte EXPIRED affiche badge EXPIRÉ', (tester) async {
    final bids = [_bid('EXPIRED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('EXPIRÉ'), findsOneWidget);
  });

  testWidgets('carte PARCEL_REFUSED affiche badge REFUSÉ', (tester) async {
    final bids = [_bid('PARCEL_REFUSED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('REFUSÉ'), findsOneWidget);
  });

  testWidgets('taper Réinitialiser dans l\'état vide filtré réinitialise le filtre',
      (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    // Create filtered empty state via search
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Réinitialiser'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();

    // Filter reset: all bids visible again
    expect(find.text('Paris → Dakar'), findsOneWidget);
  });

  testWidgets('effacer la recherche via bouton clear dans le champ', (tester) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    // Type something to show clear button
    await tester.enterText(find.byType(TextField).first, 'dakar');
    await tester.pumpAndSettle();

    // Find the clear icon button (DonySearchField uses Icons.close_rounded)
    final clearIcon = find.byIcon(Icons.close_rounded);
    expect(clearIcon, findsOneWidget);
    await tester.tap(clearIcon);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // After clear, search should be empty and both bids should show
    expect(find.text('Paris → Dakar'), findsOneWidget);
  });

  testWidgets('carte avec statut inconnu affiche le statut brut', (tester) async {
    final bids = [_bid('CUSTOM_STATUS', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    // The default case in _statusLabel should render the raw status string
    expect(find.text('CUSTOM_STATUS'), findsOneWidget);
  });

  testWidgets('mode standalone avec canGoBack=true affiche le bouton retour', (tester) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(const []),
    );

    final router = GoRouter(
      initialLocation: '/prev',
      routes: [
        GoRoute(
          path: '/prev',
          builder: (ctx, __) => Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<BidBloc>.value(value: bidBloc),
                BlocProvider<PaymentBloc>.value(value: paymentBloc),
              ],
              child: ElevatedButton(
                // push so canPop returns true
                onPressed: () => ctx.push('/envois'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/envois',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<PaymentBloc>.value(value: paymentBloc),
            ],
            child: const ShipmentListScreen(embedded: false),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Mes envois'), findsOneWidget);
    // Back button appears because canPop is true (pushed route)
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
  });
}
