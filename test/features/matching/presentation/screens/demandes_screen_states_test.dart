import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/traveler_bids_bloc.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/demandes_screen.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';
import '../../../../helpers/tracking_consent_test_helpers.dart';

class _MockTravelerBidsBloc
    extends MockBloc<TravelerBidsEvent, TravelerBidsState>
    implements TravelerBidsBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {
  @override
  Map<String, AppException> get refusals => const {};
}

class _MockAnalytics extends Mock implements AnalyticsService {}

const _helpJson = '{"schemaVersion": 1, "socialLinks": [], "tutorials": []}';

class _StaticSource implements HelpCenterConfigSource {
  const _StaticSource();

  @override
  String get activatedJson => _helpJson;

  @override
  Future<String?> fetchAndActivate() async => _helpJson;
}

final _l = lookupAppLocalizations(AppL10n.fr);

BidModel _bid(String id, {String status = 'PENDING', String? sender}) =>
    BidModel(
      id: id,
      announcementId: 'a1',
      senderId: 's1',
      senderName: sender ?? 'Expéditeur $id',
      weightKg: 5,
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TravelerBidsLoaded _loaded(
  List<BidModel> bids, {
  TravelerBidFilter filter = TravelerBidFilter.aTraiter,
  bool isLoadingMore = false,
}) => TravelerBidsLoaded(
  bids: bids,
  page: 0,
  hasMore: true,
  filter: filter,
  isLoadingMore: isLoadingMore,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const TravelerBidsRequested());
    registerFallbackValue(BidRejectRequested('x'));
    registerFallbackValue(ace.BidAcceptRequested('x'));
  });

  late _MockTravelerBidsBloc travelerBids;
  late _MockBidBloc bidBloc;
  late _MockAcceptanceBloc acceptance;
  late StreamController<TravelerBidsState> travelerStates;
  late StreamController<BidState> bidStates;
  late StreamController<acs.BidAcceptanceState> acceptanceStates;
  late List<String> visited;

  /// Erreur rendue au prochain rechargement attendu (`done`).
  Object? reloadError;

  setUp(() {
    useTrackingConsent();
    DonySnackbar.clearDedup();
    travelerBids = _MockTravelerBidsBloc();
    bidBloc = _MockBidBloc();
    acceptance = _MockAcceptanceBloc();
    travelerStates = StreamController.broadcast();
    bidStates = StreamController.broadcast();
    acceptanceStates = StreamController.broadcast();
    visited = [];
    reloadError = null;
    whenListen(bidBloc, bidStates.stream, initialState: BidInitial());
    whenListen(
      acceptance,
      acceptanceStates.stream,
      initialState: acs.BidAcceptanceInitial(),
    );
    final analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() async {
    await getIt.reset();
    await travelerStates.close();
    await bidStates.close();
    await acceptanceStates.close();
  });

  Future<void> pump(WidgetTester tester, TravelerBidsState initial) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(travelerBids, travelerStates.stream, initialState: initial);
    when(() => travelerBids.add(any())).thenAnswer((invocation) {
      final event = invocation.positionalArguments.first;
      if (event is TravelerBidsRequested) event.done?.complete(reloadError);
    });

    GoRoute stub(String path, {Object? popWith}) => GoRoute(
      path: path,
      builder: (context, state) {
        visited.add(state.uri.path);
        return Scaffold(
          body: TextButton(
            onPressed: () => context.pop(popWith),
            child: Text('stub $path'),
          ),
        );
      },
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<TravelerBidsBloc>.value(value: travelerBids),
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<BidAcceptanceBloc>.value(value: acceptance),
              BlocProvider<HelpCenterBloc>(
                create: (_) => HelpCenterBloc(
                  HelpCenterRepository(
                    const _StaticSource(),
                    fallbackJsonLoader: () async => _helpJson,
                  ),
                  makeDisabledAnalytics(MockAnalyticsBackend()),
                ),
              ),
            ],
            child: const DemandesScreenTesting(),
          ),
        ),
        stub('/bids/:bidId'),
        stub('/trips/create'),
        stub('/payments/commission-method'),
        stub('/payments/wallet/topup/method', popWith: true),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void verifyReload({int times = 1}) => verify(
    () => travelerBids.add(
      any(
        that: isA<TravelerBidsRequested>().having(
          (e) => e.force,
          'force',
          true,
        ),
      ),
    ),
  ).called(times);

  testWidgets('chargement : squelettes de cartes', (tester) async {
    await pump(tester, const TravelerBidsLoading());
    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
  });

  testWidgets('erreur : message traduit et « Réessayer » recharge', (
    tester,
  ) async {
    const error = TimeoutException();
    await pump(tester, const TravelerBidsError(error));

    expect(
      find.text(ErrorPresenter.resolve(error, l10n: _l).message),
      findsOneWidget,
    );
    await tester.tap(find.text(_l.commonRetry));
    verifyReload();
  });

  testWidgets('filtre : tap sur une pastille change le filtre', (tester) async {
    await pump(tester, _loaded([_bid('b1')]));
    await tester.tap(find.byKey(const Key('demandes-filter-acceptees')));
    verify(
      () => travelerBids.add(
        const TravelerBidsFilterChanged(TravelerBidFilter.acceptees),
      ),
    ).called(1);
  });

  testWidgets('états vides des archives « Acceptées » et « Terminées »', (
    tester,
  ) async {
    await pump(tester, _loaded(const [], filter: TravelerBidFilter.acceptees));
    expect(find.text(_l.bidListEmptyAcceptedTitle), findsOneWidget);
    expect(find.text(_l.tripPublishTitle), findsNothing);

    travelerStates.add(_loaded(const [], filter: TravelerBidFilter.terminees));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_l.bidListEmptyCompletedTitle), findsOneWidget);
  });

  testWidgets('état vide « À traiter » : « Publier un trajet » navigue', (
    tester,
  ) async {
    await pump(tester, _loaded(const []));
    await tester.tap(find.text(_l.tripPublishTitle));
    await tester.pumpAndSettle();
    expect(visited, ['/trips/create']);
  });

  testWidgets('recherche : aucun résultat puis effacement', (tester) async {
    await pump(tester, _loaded([_bid('b1', sender: 'Awa Diop')]));

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_l.bidListNoResultTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'awa');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Awa Diop'), findsOneWidget);
  });

  testWidgets('chargement de la page suivante : squelette en bas de liste', (
    tester,
  ) async {
    await pump(tester, _loaded([_bid('b1')], isLoadingMore: true));
    expect(find.byType(DonyUserCardSkeleton), findsOneWidget);
  });

  testWidgets('défilement en bas de liste : page suivante demandée', (
    tester,
  ) async {
    await pump(tester, _loaded([for (var i = 0; i < 12; i++) _bid('b$i')]));
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pump(const Duration(seconds: 1));
    verify(
      () => travelerBids.add(const TravelerBidsNextPageRequested()),
    ).called(greaterThan(0));
  });

  testWidgets('tirer pour rafraîchir : refus oubliés et rechargement', (
    tester,
  ) async {
    reloadError = const TimeoutException();
    await pump(tester, _loaded([_bid('b1')]));

    await tester.fling(find.text('Expéditeur b1'), const Offset(0, 500), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    verify(
      () => acceptance.add(any(that: isA<ace.BidAcceptanceRefusalsCleared>())),
    ).called(1);
    verifyReload();
  });

  testWidgets('tap sur la carte : détail puis rechargement au retour', (
    tester,
  ) async {
    await pump(tester, _loaded([_bid('b1')]));
    await tester.tap(find.text('Expéditeur b1'));
    await tester.pumpAndSettle();
    expect(visited, ['/bids/b1']);

    await tester.tap(find.text('stub /bids/:bidId'));
    await tester.pumpAndSettle();
    verifyReload();
  });

  testWidgets('Refuser : motif choisi → BidRejectRequested', (tester) async {
    await pump(tester, _loaded([_bid('b1')]));
    await tester.tap(find.text(_l.bidListDeclineButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.bidRejectionReasonTripChanged));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.bidDetailConfirmDecline));
    await tester.pumpAndSettle();

    verify(
      () => bidBloc.add(
        any(
          that: isA<BidRejectRequested>().having(
            (e) => e.reason,
            'reason',
            'TRIP_CHANGED',
          ),
        ),
      ),
    ).called(1);
  });

  group('écouteur BidBloc', () {
    testWidgets('BidAccepted : snackbar, rechargement attendu', (tester) async {
      await pump(tester, _loaded([_bid('b1')]));
      await tester.tap(find.text(_l.bidListAcceptButton));
      await tester.pump();
      verify(() => bidBloc.add(any(that: isA<BidAcceptRequested>()))).called(1);

      bidStates.add(BidAccepted(_bid('b1')));
      await settle(tester);

      expect(find.text(_l.bidListAcceptedSnackbar), findsOneWidget);
      verifyReload();
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('BidRejected : snackbar et rechargement', (tester) async {
      await pump(tester, _loaded([_bid('b1')]));
      bidStates.add(BidRejected(_bid('b1')));
      await settle(tester);

      expect(find.text(_l.bidListRejectedSnackbar), findsOneWidget);
      verifyReload();
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('BidError après une acceptation : message d\'erreur', (
      tester,
    ) async {
      await pump(tester, _loaded([_bid('b1')]));
      await tester.tap(find.text(_l.bidListAcceptButton));
      await tester.pump();

      const error = TimeoutException();
      bidStates.add(BidError(error));
      await settle(tester);

      expect(
        find.text(ErrorPresenter.resolve(error, l10n: _l).message),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('écouteur BidAcceptanceBloc', () {
    testWidgets('acceptation espèces réussie : snackbar et rechargement', (
      tester,
    ) async {
      await pump(tester, _loaded([_bid('b1')]));
      acceptanceStates.add(acs.BidAccepted());
      await settle(tester);

      expect(find.text(_l.bidListAcceptedSnackbar), findsOneWidget);
      verifyReload();
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('refus définitif : message et rechargement', (tester) async {
      await pump(tester, _loaded([_bid('b1')]));
      acceptanceStates.add(
        acs.BidFailed(
          reason: acs.BidFailureReason.confirmFailed,
          definitive: true,
        ),
      );
      await settle(tester);

      expect(find.text(_l.bidAcceptConfirmFailed), findsOneWidget);
      verifyReload();
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    acs.BidWalletInsufficient shortfall({required bool hasCard}) =>
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: hasCard,
          bidId: 'b1',
          currency: 'EUR',
        );

    testWidgets('solde insuffisant : recharge réussie → acceptation relancée', (
      tester,
    ) async {
      await pump(tester, _loaded([_bid('b1')]));
      acceptanceStates.add(shortfall(hasCard: false));
      await tester.pumpAndSettle();

      expect(find.text(_l.bidListWalletInsufficientTitle), findsOneWidget);
      expect(find.text(_l.bidListWalletInsufficientHint), findsOneWidget);

      await tester.tap(find.text(_l.walletShortfallTopupInCurrency('EUR')));
      await tester.pumpAndSettle();
      expect(visited, ['/payments/wallet/topup/method']);
      await tester.tap(find.text('stub /payments/wallet/topup/method'));
      await tester.pumpAndSettle();

      verify(
        () => acceptance.add(
          any(
            that: isA<ace.BidAcceptRequested>().having(
              (e) => e.bidId,
              'bidId',
              'b1',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('solde insuffisant avec carte : payer par carte', (
      tester,
    ) async {
      await pump(tester, _loaded([_bid('b1')]));
      acceptanceStates.add(shortfall(hasCard: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_l.bidListPayByCardButton));
      await tester.pumpAndSettle();
      verify(
        () => acceptance.add(any(that: isA<ace.BidAcceptWithCardRequested>())),
      ).called(1);
    });

    testWidgets('solde insuffisant sans carte : ajout puis rechargement', (
      tester,
    ) async {
      await pump(tester, _loaded([_bid('b1')]));
      acceptanceStates.add(shortfall(hasCard: false));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_l.bidListAddCardButton));
      await tester.pumpAndSettle();
      expect(visited, ['/payments/commission-method']);

      await tester.tap(find.text('stub /payments/commission-method'));
      await tester.pumpAndSettle();
      verifyReload();
    });
  });
}
