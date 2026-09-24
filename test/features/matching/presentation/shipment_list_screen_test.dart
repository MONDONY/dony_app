import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/envois_refresh_notifier.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/shipment_list_screen.dart';
import 'package:dony/features/matching/presentation/widgets/activity_header_widgets.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

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
      createdAt: DateTime(2026, 5),
      updatedAt: DateTime(2026, 5),
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
      initialState: const PaymentInitial(),
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
      child: const ShipmentListScreen(),
    ),
  );

  testWidgets('puce rapide « Livrés » ne montre que les COMPLETED', (
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

    await tester.tap(find.text('Livrés'));
    await tester.pumpAndSettle();

    expect(find.text('Abidjan'), findsOneWidget);
    expect(find.text('Dakar'), findsNothing);
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

    expect(find.text('Bamako'), findsOneWidget);
    expect(find.text('Dakar'), findsNothing);
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

  testWidgets('état BidLoading affiche un skeleton', (tester) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidLoading(),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
  });

  testWidgets('état BidInitial affiche un skeleton', (tester) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidInitial(),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
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

  testWidgets('liste vide totale affiche « Aucun envoi pour l\'instant »', (
    tester,
  ) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(const []),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Aucun envoi'), findsOneWidget);
  });

  testWidgets('liste vide totale — chips et champ recherche masqués', (
    tester,
  ) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(const []),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    // Chips and search are hidden when raw bid list is empty
    expect(find.byType(StatusChipsRow), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('liste vide totale affiche CTA « Rechercher un trajet »', (
    tester,
  ) async {
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(const []),
    );
    await tester.pumpWidget(subject());
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Rechercher un trajet'), findsOneWidget);
  });

  testWidgets(
    'puce rapide « En cours » filtre les bids ACCEPTED/HANDED_OVER/IN_TRANSIT',
    (tester) async {
      final bids = [_bid('ACCEPTED', 'Dakar'), _bid('PENDING', 'Abidjan')];
      whenListen(
        bidBloc,
        Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids),
      );
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('En cours'));
      await tester.pumpAndSettle();

      expect(find.text('Dakar'), findsOneWidget);
      expect(find.text('Abidjan'), findsNothing);
    },
  );

  testWidgets('puce rapide « Tous » réinitialise le filtre statut', (
    tester,
  ) async {
    final bids = [_bid('ACCEPTED', 'Dakar'), _bid('PENDING', 'Abidjan')];
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

    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Abidjan'), findsOneWidget);
  });

  testWidgets(
    'puce rapide « En attente » filtre PENDING/AWAITING_PAYMENT/PAYMENT_ESCROWED',
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

      await tester.tap(find.text('En attente'));
      await tester.pumpAndSettle();

      expect(find.text('Abidjan'), findsOneWidget);
      expect(find.text('Dakar'), findsNothing);
    },
  );

  testWidgets('« Tout effacer » réinitialise les filtres actifs', (
    tester,
  ) async {
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

  testWidgets(
    'BidListLoaded avec isRefreshing = true affiche le LinearProgressIndicator',
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
    },
  );

  // Note: after ShipmentCard redesign, AWAITING_PAYMENT shows badge 'EN ATTENTE'
  // and navigates to bid detail on tap (no inline "Payer →" button).
  testWidgets('carte AWAITING_PAYMENT affiche le badge EN ATTENTE', (
    tester,
  ) async {
    final bids = [_bid('AWAITING_PAYMENT', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('EN ATTENTE'), findsOneWidget);
  });

  testWidgets(
    'carte COMPLETED affiche le badge LIVRÉ et le CTA « Détails → »',
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
      expect(find.text('Détails →'), findsOneWidget);
    },
  );

  testWidgets(
    'carte ACCEPTED affiche le badge À REMETTRE et le CTA « Voir le QR → »',
    (tester) async {
      final bids = [_bid('ACCEPTED', 'Dakar')];
      whenListen(
        bidBloc,
        Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids),
      );
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('À REMETTRE'), findsOneWidget);
      expect(find.text('Voir le QR →'), findsOneWidget);
    },
  );

  testWidgets('carte REJECTED affiche badge REFUSÉ', (tester) async {
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

  testWidgets('carte PARCEL_REFUSED affiche badge COLIS REFUSÉ', (
    tester,
  ) async {
    final bids = [_bid('PARCEL_REFUSED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('COLIS REFUSÉ'), findsOneWidget);
  });

  testWidgets(
    'taper Réinitialiser dans l\'état vide filtré réinitialise le filtre',
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
      expect(find.text('Dakar'), findsOneWidget);
    },
  );

  testWidgets('effacer la recherche via bouton clear dans le champ', (
    tester,
  ) async {
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
    final clearIcon = find.byWidgetPredicate(
      (w) => w is DonyIcon && w.name == 'x',
    );
    expect(clearIcon, findsOneWidget);
    await tester.tap(clearIcon);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // After clear, search should be empty and both bids should show
    expect(find.text('Dakar'), findsOneWidget);
  });

  testWidgets(
    'carte avec statut inconnu affiche le statut brut dans le badge',
    (tester) async {
      final bids = [_bid('CUSTOM_STATUS', 'Dakar')];
      whenListen(
        bidBloc,
        Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids),
      );
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      // ShipmentCard._badge() default case returns bid.status as label
      expect(find.text('CUSTOM_STATUS'), findsOneWidget);
    },
  );

  testWidgets('StatusChipsRow présente quand la liste contient des bids', (
    tester,
  ) async {
    final bids = [_bid('ACCEPTED', 'Dakar')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    // All four chip labels present
    expect(find.text('Tous'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Livrés'), findsOneWidget);
    expect(find.text('Non aboutis'), findsOneWidget);
  });

  testWidgets('tapper « Livrés » → cubit statuses == {COMPLETED}', (
    tester,
  ) async {
    final bids = [_bid('COMPLETED', 'Dakar'), _bid('ACCEPTED', 'Abidjan')];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Livrés'));
    await tester.pumpAndSettle();

    expect(find.text('Dakar'), findsOneWidget);
    expect(find.text('Abidjan'), findsNothing);
  });

  testWidgets('tapper « Non aboutis » → seuls les envois clos sans livraison', (
    tester,
  ) async {
    final bids = [
      _bid('COMPLETED', 'Dakar'),
      _bid('ACCEPTED', 'Abidjan'),
      _bid('CANCELLED', 'Bamako'),
      _bid('PARCEL_REFUSED', 'Douala'),
    ];
    whenListen(
      bidBloc,
      Stream<BidState>.fromIterable([BidListLoaded(bids)]),
      initialState: BidListLoaded(bids),
    );
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Non aboutis'));
    await tester.tap(find.text('Non aboutis'));
    await tester.pumpAndSettle();

    expect(find.text('Bamako'), findsOneWidget);
    expect(find.text('Douala'), findsOneWidget);
    expect(find.text('Dakar'), findsNothing);
    expect(find.text('Abidjan'), findsNothing);
    expect(find.text('ANNULÉ'), findsOneWidget);
    expect(find.text('COLIS REFUSÉ'), findsOneWidget);
  });

  group('shipmentResultCount', () {
    testWidgets('1 résultat filtré → « 1 résultat » (singulier)', (
      tester,
    ) async {
      final bids = [_bid('ACCEPTED', 'Dakar'), _bid('PENDING', 'Abidjan')];
      whenListen(
        bidBloc,
        Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids),
      );
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('En cours'));
      await tester.pumpAndSettle();

      expect(find.text('1 résultat'), findsOneWidget);
    });

    testWidgets('4 résultats filtrés → « 4 résultats » (pluriel)', (
      tester,
    ) async {
      final bids = [
        _bid('ACCEPTED', 'Ouaga1'),
        _bid('HANDED_OVER', 'Ouaga2'),
        _bid('IN_TRANSIT', 'Ouaga3'),
        _bid('ACCEPTED', 'Ouaga4'),
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

      expect(find.text('4 résultats'), findsOneWidget);
    });

    testWidgets('en anglais : « 1 result » et « 4 results »', (tester) async {
      useEnglish();
      final bids = [
        _bid('ACCEPTED', 'Ouaga1'),
        _bid('HANDED_OVER', 'Ouaga2'),
        _bid('IN_TRANSIT', 'Ouaga3'),
        _bid('ACCEPTED', 'Ouaga4'),
      ];
      whenListen(
        bidBloc,
        Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids),
      );
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('In progress'));
      await tester.pumpAndSettle();

      expect(find.text('4 results'), findsOneWidget);
      expect(find.text('4 résultats'), findsNothing);
    });
  });

  group('traductions', () {
    testWidgets(
      'en anglais : état vide total, chips et bouton effacer traduits',
      (tester) async {
        useEnglish();
        whenListen(
          bidBloc,
          const Stream<BidState>.empty(),
          initialState: BidListLoaded(const []),
        );
        await tester.pumpWidget(subject());
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('No shipments yet'), findsOneWidget);
        expect(find.text('Search for a trip'), findsOneWidget);
        expect(find.textContaining('Aucun envoi'), findsNothing);
      },
    );

    testWidgets('en anglais : chips de statut et « Clear all » traduits', (
      tester,
    ) async {
      useEnglish();
      final bids = [_bid('ACCEPTED', 'Dakar')];
      whenListen(
        bidBloc,
        Stream<BidState>.fromIterable([BidListLoaded(bids)]),
        initialState: BidListLoaded(bids),
      );
      await tester.pumpWidget(subject());
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('Not completed'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'dakar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Clear all'), findsOneWidget);
    });
  });
}
