import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/auth_bloc.dart';
import 'package:dony/features/auth/bloc/auth_event.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/screens/trip_owner_detail_screen.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/features/tracking/bloc/trip_depart_cubit.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/trip_tracking_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/map_backed_box.dart';
import '../../../../helpers/stripe_account_test_doubles.dart';
import '../../../../helpers/trip_answer_blocs.dart';

class _MockAnnBloc extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockCancelBloc extends MockBloc<CancellationEvent, CancellationState>
    implements CancellationBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockAudience extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

class _FakeContext extends Fake implements BuildContext {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockTracking extends Mock implements TripTrackingRepository {}

class _MockLocator extends Mock implements ScanLocator {}

class _MockConsent extends Mock implements TrackingConsentCubit {}

const _ownerId = 'trav-001';
const _owner = UserModel(
  id: _ownerId,
  roles: [],
  kycStatus: 'VERIFIED',
  status: 'ACTIVE',
);

AnnouncementModel _ann({
  bool trackingActive = false,
  TripParcelsSummary? summary,
  String status = 'ACTIVE',
}) => AnnouncementModel(
  id: 'ann-trip-001',
  travelerId: _ownerId,
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 7),
  availableKg: 10,
  totalKg: 23,
  pricePerKg: 8,
  status: status,
  bidsCount: 0,
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
  trackingActive: trackingActive,
  parcelsSummary: summary,
);

const _summary = TripParcelsSummary(
  count: 2,
  totalKg: 7.5,
  netAmount: 42,
  currency: 'EUR',
);

void main() {
  late _MockAnnBloc annBloc;
  late _MockBidBloc bidBloc;
  late _MockCancelBloc cancelBloc;
  late _MockAuthBloc authBloc;
  late _MockAnalytics analytics;
  late _MockTracking tracking;
  late _MockLocator locator;
  late _MockConsent consent;
  late Map<String, dynamic> stored;

  setUpAll(() async {
    await initializeDateFormatting('fr');
    registerFallbackValue(BidListRequested('fallback'));
    registerFallbackValue(TrackingConsentSource.depart);
    registerFallbackValue(_FakeContext());
  });

  setUp(() {
    DonySnackbar.clearDedup();
    annBloc = _MockAnnBloc();
    bidBloc = _MockBidBloc();
    cancelBloc = _MockCancelBloc();
    authBloc = _MockAuthBloc();
    analytics = _MockAnalytics();
    tracking = _MockTracking();
    locator = _MockLocator();
    consent = _MockConsent();
    stored = <String, dynamic>{};

    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => analytics.logScreen(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(
      () => consent.ensureAsked(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => false);
    when(
      () => locator.lastKnownCoordinatesIfGranted(),
    ).thenAnswer((_) async => null);
    when(
      () => locator.captureCoordinatesIfGranted(),
    ).thenAnswer((_) async => const ScanPosition(lat: 48.85, lon: 2.35));
    when(
      () => tracking.depart(
        any(),
        lat: any(named: 'lat'),
        lon: any(named: 'lon'),
      ),
    ).thenAnswer((_) async {});

    when(() => authBloc.state).thenReturn(const AuthAuthenticated(_owner));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthAuthenticated(_owner),
    );
    when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
    whenListen(
      bidBloc,
      const Stream<BidState>.empty(),
      initialState: BidListLoaded(const []),
    );
    when(() => cancelBloc.state).thenReturn(CancellationInitial());
    whenListen(
      cancelBloc,
      const Stream<CancellationState>.empty(),
      initialState: CancellationInitial(),
    );

    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<TrackingConsentCubit>()) {
      getIt.unregister<TrackingConsentCubit>();
    }
    if (getIt.isRegistered<TripDepartCubit>()) {
      getIt.unregister<TripDepartCubit>();
    }
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    getIt.registerSingleton<TrackingConsentCubit>(consent);
    registerInertTripAnswerBlocs();
    getIt.registerFactoryParam<TripDepartCubit, String, void>(
      (id, _) => TripDepartCubit(
        announcementId: id,
        tracking: tracking,
        locator: locator,
        consent: consent,
        analytics: analytics,
        box: () => mapBackedBox(stored),
      ),
    );
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    if (getIt.isRegistered<TrackingConsentCubit>()) {
      getIt.unregister<TrackingConsentCubit>();
    }
    if (getIt.isRegistered<TripDepartCubit>()) {
      getIt.unregister<TripDepartCubit>();
    }
  });

  Future<void> pump(WidgetTester tester, AnnouncementModel a) async {
    when(() => annBloc.state).thenReturn(AnnouncementDetailLoaded(a));
    whenListen(
      annBloc,
      const Stream<AnnouncementState>.empty(),
      initialState: AnnouncementDetailLoaded(a),
    );
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AnnouncementBloc>.value(value: annBloc),
              BlocProvider<BidBloc>.value(value: bidBloc),
              BlocProvider<CancellationBloc>.value(value: cancelBloc),
              BlocProvider<TripAudienceCubit>.value(value: _hiddenAudience()),
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<StripeAccountBloc>.value(
                value: stubStripeAccountBloc(),
              ),
            ],
            child: const TripOwnerDetailScreen(announcementId: 'ann-trip-001'),
          ),
        ),
        GoRoute(
          path: '/announcements/:id/bids',
          builder: (ctx, s) =>
              Scaffold(body: Text('BIDS:${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  const departKey = Key('trip-depart-button');

  // Gain du trajet : au titre de la ligne Colis, détaillé en tête du sheet
  // « Colis » (ni case Gain ni carte dans le corps).
  group('résumé du trajet', () {
    final line = find.byKey(const Key('trip-parcels-line'));
    final gainBlock = find.byKey(const Key('trip-activity-parcels-gain'));
    String lineTitle(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('trip-parcels-line-title')))
        .data!;
    Future<void> openParcels(WidgetTester tester) async {
      await tester.tap(line);
      await settle(tester);
    }

    // Liste chargée et vide alors que le détail sert un net (données
    // incohérentes) : jamais « Aucun colis · 42 € » au titre.
    testWidgets('gainNotInTitleWhileLoadedListIsEmpty', (tester) async {
      await pump(tester, _ann(summary: _summary));
      expect(find.byKey(const Key('trip-summary-card')), findsNothing);
      expect(find.byKey(const Key('trip-activity-gain')), findsNothing);
      expect(lineTitle(tester), 'Aucun colis');
      expect(lineTitle(tester), isNot(contains('42')));
      expect(lineTitle(tester), isNot(contains('·')));
    });

    testWidgets('gainHiddenWhenNothingIsEarned', (tester) async {
      for (final summary in const [
        null,
        TripParcelsSummary(count: 0, totalKg: 0, netAmount: 0, currency: 'EUR'),
        // Colis remis payés en espèces, liste encore vide : rien de connu.
        TripParcelsSummary(count: 1, totalKg: 3, netAmount: 0, currency: 'EUR'),
      ]) {
        await pump(tester, _ann(summary: summary));
        expect(line, findsOneWidget);
        expect(lineTitle(tester), isNot(contains('·')));
        await openParcels(tester);
        expect(gainBlock, findsNothing);
      }
    });

    // La liste des colis s'ouvre par le pied du sheet « Colis » ; le bloc
    // du gain est en lecture seule.
    testWidgets('gainBlockHasNoButton', (tester) async {
      await pump(tester, _ann(summary: _summary));
      await openParcels(tester);
      expect(
        find.descendant(of: gainBlock, matching: find.byType(DonyButton)),
        findsNothing,
      );
      expect(
        find.byKey(const Key('trip-activity-parcels-open-list')),
        findsOneWidget,
      );
      expect(find.text('Voir mes colis'), findsNothing);
    });
  });

  // « Je pars » : tuile « À traiter » de l'écran, qui ouvre son sheet ; le
  // bouton du pied du sheet part sur le TripDepartCubit fourni par l'écran.
  group('je pars', () {
    const departTile = Key('trip_owner-todo-depart');

    Future<void> openDepart(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(departTile));
      await tester.tap(find.byKey(departTile));
      await settle(tester);
      expect(find.byKey(departKey), findsOneWidget);
    }

    testWidgets('departSendsPositionWhenGranted', (tester) async {
      when(
        () => consent.ensureAsked(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => true);
      await pump(tester, _ann(trackingActive: true, summary: _summary));
      await openDepart(tester);
      await tester.tap(find.byKey(departKey));
      await settle(tester);
      verify(
        () => tracking.depart('ann-trip-001', lat: 48.85, lon: 2.35),
      ).called(1);
      // Départ confirmé : confirmation, le sheet se ferme et la tuile
      // disparaît (même cubit pour l'écran et le sheet).
      expect(find.text("C'est noté, bon voyage !"), findsOneWidget);
      expect(find.byKey(departKey), findsNothing);
      expect(find.byKey(departTile), findsNothing);
    });

    testWidgets('departWithoutPositionStillCallsApi', (tester) async {
      when(
        () => consent.ensureAsked(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => true);
      when(
        () => locator.captureCoordinatesIfGranted(),
      ).thenAnswer((_) async => null);
      await pump(tester, _ann(trackingActive: true, summary: _summary));
      await openDepart(tester);
      await tester.tap(find.byKey(departKey));
      await settle(tester);
      verify(() => tracking.depart('ann-trip-001')).called(1);
    });

    testWidgets('refusalStillAllowsDepart', (tester) async {
      when(
        () => consent.ensureAsked(any(), source: any(named: 'source')),
      ).thenAnswer((_) async => false);
      when(
        () => locator.captureCoordinatesIfGranted(),
      ).thenAnswer((_) async => null);
      await pump(tester, _ann(trackingActive: true, summary: _summary));
      await openDepart(tester);
      await tester.tap(find.byKey(departKey));
      await settle(tester);
      verify(
        () => consent.ensureAsked(any(), source: TrackingConsentSource.depart),
      ).called(1);
      verify(() => tracking.depart('ann-trip-001')).called(1);
    });

    testWidgets('sheetClosedDuringDepartStillConfirmsOnScreen', (tester) async {
      final reply = Completer<void>();
      when(
        () => tracking.depart(
          any(),
          lat: any(named: 'lat'),
          lon: any(named: 'lon'),
        ),
      ).thenAnswer((_) => reply.future);
      await pump(tester, _ann(trackingActive: true, summary: _summary));
      await openDepart(tester);
      await tester.tap(find.byKey(departKey));
      await tester.pump();
      // Le voyageur referme le sheet, réponse encore en vol.
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(find.byKey(departKey), findsNothing);

      reply.complete();
      await settle(tester);
      expect(find.text("C'est noté, bon voyage !"), findsOneWidget);
      expect(find.byKey(departTile), findsNothing);
    });

    testWidgets('departTileHiddenAfterConfirmation', (tester) async {
      stored['${HiveService.kTripDepartedPrefix}ann-trip-001'] = true;
      await pump(tester, _ann(trackingActive: true, summary: _summary));
      expect(find.byKey(departTile), findsNothing);
    });

    testWidgets('departTileHiddenWithoutTrackingActive', (tester) async {
      await pump(tester, _ann(summary: _summary));
      expect(find.byKey(departTile), findsNothing);
    });

    testWidgets('departTileHiddenWithoutParcelsSummary', (tester) async {
      await pump(tester, _ann(trackingActive: true));
      expect(find.byKey(departTile), findsNothing);
    });

    // Piège n°1 de l'inventaire : un back antérieur à la PR jumelle ne sert
    // pas `trackingActive` dans le détail (contrat ancien). Un détail relu
    // sans lui retire la tuile, rien ne casse.
    testWidgets('detailWithoutTrackingActiveHidesTileWithoutError', (
      tester,
    ) async {
      await pump(tester, _ann(summary: _summary));
      expect(find.byKey(departTile), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('ensureAskedCalledOnceWhenOpenedWhileTrackingActive', (
    tester,
  ) async {
    await pump(tester, _ann(trackingActive: true, summary: _summary));
    verify(
      () =>
          consent.ensureAsked(any(), source: TrackingConsentSource.tripScreen),
    ).called(1);
  });

  testWidgets('ensureAskedNotCalledWhenTrackingInactive', (tester) async {
    await pump(tester, _ann(summary: _summary));
    verifyNever(() => consent.ensureAsked(any(), source: any(named: 'source')));
  });

  // Le back sert la fenêtre de suivi sans regarder le statut : un trajet
  // annulé dont un colis remis suit la procédure de retour la verrait encore
  // ouverte. Le consentement suit la règle de « Je pars ».
  for (final status in const ['FULL', 'IN_PROGRESS']) {
    testWidgets('consentement proposé sur un trajet $status', (tester) async {
      await pump(
        tester,
        _ann(trackingActive: true, summary: _summary, status: status),
      );
      verify(
        () => consent.ensureAsked(
          any(),
          source: TrackingConsentSource.tripScreen,
        ),
      ).called(1);
    });
  }

  for (final status in const [
    'CANCELLED',
    'COMPLETED',
    'DRAFT',
    'REMOVED_BY_ADMIN',
  ]) {
    testWidgets('consentement jamais proposé sur un trajet $status', (
      tester,
    ) async {
      await pump(
        tester,
        _ann(trackingActive: true, summary: _summary, status: status),
      );
      verifyNever(
        () => consent.ensureAsked(any(), source: any(named: 'source')),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

TripAudienceCubit _hiddenAudience() {
  final cubit = _MockAudience();
  when(() => cubit.state).thenReturn(const TripAudienceState.hidden());
  when(() => cubit.load(any())).thenAnswer((_) async {});
  return cubit;
}
