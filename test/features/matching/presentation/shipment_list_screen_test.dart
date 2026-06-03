import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
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
}
