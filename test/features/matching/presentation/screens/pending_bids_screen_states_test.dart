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
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/screens/pending_bids_screen.dart';
import 'package:dony/features/settings/bloc/business_prefs_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockPrefsBloc extends MockBloc<BusinessPrefsEvent, BusinessPrefsState>
    implements BusinessPrefsBloc {}

class _MockAnalytics extends Mock implements AnalyticsService {}

final _l = lookupAppLocalizations(AppL10n.fr);

BidModel _bid(
  String id, {
  String status = 'PENDING',
  double? pricePerKg = 15,
  BidPaymentMethod method = BidPaymentMethod.cash,
}) => BidModel(
  id: id,
  announcementId: 'ann-1',
  senderId: 'sender-1',
  senderName: 'Moussa Traoré',
  weightKg: 3,
  pricePerKg: pricePerKg,
  status: status,
  paymentMethod: method,
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

void main() {
  setUpAll(() {
    registerFallbackValue(BidListRequested('ann-1'));
    registerFallbackValue(ace.BidAcceptRequested('x'));
    registerFallbackValue(const MinBidPriceChanged(0));
  });

  late _MockBidBloc bidBloc;
  late _MockAcceptanceBloc acceptanceBloc;
  late StreamController<BidState> bidStates;
  late StreamController<acs.BidAcceptanceState> acceptanceStates;
  late List<String> pushed;

  setUp(() async {
    await initializeDateFormatting('fr_FR');
    DonySnackbar.clearDedup();
    bidBloc = _MockBidBloc();
    acceptanceBloc = _MockAcceptanceBloc();
    bidStates = StreamController<BidState>.broadcast();
    acceptanceStates = StreamController<acs.BidAcceptanceState>.broadcast();
    pushed = [];
    whenListen(bidBloc, bidStates.stream, initialState: BidInitial());
    whenListen(
      acceptanceBloc,
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
    await bidStates.close();
    await acceptanceStates.close();
  });

  GoRoute stub(String path) => GoRoute(
    path: path,
    builder: (_, state) {
      pushed.add(state.uri.toString());
      return Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => context.pop(),
            child: Text('stub $path'),
          ),
        ),
      );
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    Widget? screen,
    String initial = '/start',
  }) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/screen'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/screen',
          builder: (_, _) =>
              screen ??
              MultiBlocProvider(
                providers: [
                  BlocProvider<BidBloc>.value(value: bidBloc),
                  BlocProvider<BidAcceptanceBloc>.value(value: acceptanceBloc),
                ],
                child: const PendingBidsScreenTesting(announcementId: 'ann-1'),
              ),
        ),
        stub('/home'),
        stub('/payments/commission-method'),
        stub('/bids/:id'),
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
    await tester.pump();
    if (initial == '/start') {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('écran réel : blocs résolus par getIt et liste demandée', (
    tester,
  ) async {
    getIt
      ..registerFactory<BidBloc>(() => bidBloc)
      ..registerFactory<BidAcceptanceBloc>(() => acceptanceBloc);
    await pump(
      tester,
      screen: const PendingBidsScreen(announcementId: 'ann-1'),
    );

    verify(
      () => bidBloc.add(
        any(
          that: isA<BidListRequested>().having(
            (e) => e.announcementId,
            'announcementId',
            'ann-1',
          ),
        ),
      ),
    ).called(1);
    expect(find.text(_l.bidListFilterToReview), findsOneWidget);
  });

  testWidgets('chargement : squelettes de cartes', (tester) async {
    await pump(tester);
    bidStates.add(BidLoading());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(DonyUserCardSkeleton), findsWidgets);
  });

  testWidgets('erreur : message traduit, « Réessayer » relance la liste', (
    tester,
  ) async {
    await pump(tester);
    const error = TimeoutException();
    bidStates.add(BidError(error));
    await tester.pumpAndSettle();

    final message = ErrorPresenter.resolve(error, l10n: _l).message;
    expect(find.text(message), findsWidgets);
    clearInteractions(bidBloc);

    await tester.tap(find.text(_l.commonRetry));
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
  });

  testWidgets('refus réussi : snackbar et rechargement', (tester) async {
    await pump(tester);
    bidStates.add(BidRejected(_bid('b-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_l.bidListRejectedSnackbar), findsOneWidget);
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('suppression réussie : snackbar et rechargement', (tester) async {
    await pump(tester);
    bidStates.add(BidDeleted());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(_l.bidListDeletedSnackbar), findsOneWidget);
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('trajet disparu, écran poussé : retour arrière', (tester) async {
    await pump(tester);
    bidStates.add(BidNotFound());
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text(_l.listingAnnouncementGoneMessage), findsOneWidget);
  });

  testWidgets('trajet disparu, écran racine : redirection /home', (
    tester,
  ) async {
    await pump(tester, initial: '/screen');
    bidStates.add(BidNotFound());
    await tester.pumpAndSettle();

    expect(pushed, ['/home']);
  });

  testWidgets('BidError pendant une acceptation : boutons réactivés', (
    tester,
  ) async {
    await pump(tester);
    bidStates.add(
      BidListLoaded([_bid('b-1', method: BidPaymentMethod.stripe)]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l.bidListAcceptButton));
    await tester.pump();
    verify(() => bidBloc.add(any(that: isA<BidAcceptRequested>()))).called(1);

    bidStates.add(BidError(const TimeoutException()));
    await tester.pumpAndSettle();
    // Après l'erreur, la liste n'est plus affichée (état erreur) : le bouton
    // de relance est proposé.
    expect(find.text(_l.commonRetry), findsOneWidget);
  });

  testWidgets('refus : motif choisi → BidRejectRequested avec le code', (
    tester,
  ) async {
    await pump(tester);
    bidStates.add(BidListLoaded([_bid('b-1')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l.bidListDeclineButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.bidRejectionReasonNoCapacity));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l.bidDetailConfirmDecline));
    await tester.pumpAndSettle();

    verify(
      () => bidBloc.add(
        any(
          that: isA<BidRejectRequested>()
              .having((e) => e.bidId, 'bidId', 'b-1')
              .having((e) => e.reason, 'reason', 'NO_CAPACITY'),
        ),
      ),
    ).called(1);
  });

  testWidgets('tap sur la carte : détail puis rechargement au retour', (
    tester,
  ) async {
    await pump(tester);
    bidStates.add(BidListLoaded([_bid('b-7')]));
    await tester.pumpAndSettle();
    clearInteractions(bidBloc);

    await tester.tap(find.text('Moussa Traoré'));
    await tester.pumpAndSettle();
    expect(pushed, ['/bids/b-7']);

    await tester.tap(find.text('stub /bids/:id'));
    await tester.pumpAndSettle();
    verify(() => bidBloc.add(any(that: isA<BidListRequested>()))).called(1);
  });

  group('acceptation espèces', () {
    testWidgets('BidAccepted sans demande connue : snackbar de succès', (
      tester,
    ) async {
      await pump(tester);
      acceptanceStates.add(acs.BidAccepted());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(_l.bidListAcceptedSnackbar), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('échec simple : snackbar d\'erreur', (tester) async {
      await pump(tester);
      acceptanceStates.add(
        acs.BidFailed(reason: acs.BidFailureReason.confirmFailed),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(_l.bidAcceptConfirmFailed), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets(
      'carte de commission refusée : feuille dédiée → changer de carte',
      (tester) async {
        await pump(tester);
        acceptanceStates.add(
          acs.BidFailed(
            reason: acs.BidFailureReason.confirmFailed,
            cardDeclined: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(_l.bidListCardDeclinedSheetTitle), findsOneWidget);
        expect(find.text(_l.bidListCardDeclinedHint), findsOneWidget);
        expect(find.text(_l.bidAcceptConfirmFailed), findsOneWidget);

        await tester.tap(find.text(_l.bidListChangeCommissionCardButton));
        await tester.pumpAndSettle();
        expect(pushed, ['/payments/commission-method']);
      },
    );

    testWidgets('solde insuffisant avec carte : payer par carte', (
      tester,
    ) async {
      await pump(tester);
      acceptanceStates.add(
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: true,
          bidId: 'w-2',
          currency: 'EUR',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l.bidListWalletInsufficientTitle), findsOneWidget);
      await tester.tap(find.text(_l.bidListPayByCardButton));
      await tester.pumpAndSettle();

      verify(
        () => acceptanceBloc.add(
          any(
            that: isA<ace.BidAcceptWithCardRequested>().having(
              (e) => e.bidId,
              'bidId',
              'w-2',
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('solde insuffisant sans carte : ajouter une carte', (
      tester,
    ) async {
      await pump(tester);
      acceptanceStates.add(
        acs.BidWalletInsufficient(
          availableBalance: 1,
          requiredCommission: 5,
          hasCard: false,
          bidId: 'w-3',
          currency: 'EUR',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(_l.bidListAddCardButton));
      await tester.pumpAndSettle();
      expect(pushed, ['/payments/commission-method']);
    });
  });

  group('filtre prix minimum (BusinessPrefsBloc)', () {
    late _MockPrefsBloc prefs;

    setUp(() {
      prefs = _MockPrefsBloc();
      getIt.registerSingleton<BusinessPrefsBloc>(prefs);
    });

    testWidgets('offres sous le seuil masquées, « Voir tout » lève le filtre', (
      tester,
    ) async {
      whenListen(
        prefs,
        const Stream<BusinessPrefsState>.empty(),
        initialState: const BusinessPrefsState(minBidPriceEur: 10),
      );
      await pump(tester);
      bidStates.add(
        BidListLoaded([
          _bid('cheap', pricePerKg: 5),
          _bid('ok', pricePerKg: 20),
          _bid('noprice', pricePerKg: null),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l.bidListHiddenOffers(1)), findsOneWidget);
      expect(find.text(_l.bidListPendingTitleWithCount(3)), findsOneWidget);

      await tester.tap(find.text(_l.commonSeeAll));
      verify(
        () => prefs.add(
          any(
            that: isA<MinBidPriceChanged>().having((e) => e.euros, 'euros', 0),
          ),
        ),
      ).called(1);
    });

    testWidgets('toutes les offres masquées : état vide de la liste', (
      tester,
    ) async {
      whenListen(
        prefs,
        const Stream<BusinessPrefsState>.empty(),
        initialState: const BusinessPrefsState(minBidPriceEur: 50),
      );
      await pump(tester);
      bidStates.add(BidListLoaded([_bid('cheap', pricePerKg: 5)]));
      await tester.pumpAndSettle();

      expect(find.text(_l.bidListHiddenOffers(1)), findsOneWidget);
      expect(find.text(_l.bidListEmptyPendingTitle), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
