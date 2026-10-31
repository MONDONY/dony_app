// Harnais des tests de la réponse directe aux demandes de l'écran du trajet
// (carte « Demande 1 sur N », sheets « Activité du trajet ») : blocs de
// l'écran simulés et pilotés par des flux, blocs de réponse simulés,
// routeur qui note les écrans ouverts et sait revenir.
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/bloc/trip_audience_cubit.dart';
import 'package:dony/features/matching/bloc/trip_group_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/commission_allocation_preview.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_bid_answer.dart';
import 'package:dony/features/tracking/bloc/tracking_consent_cubit.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

export 'trip_card_harness.dart' show loadAppFonts;

class MockAnnouncementBloc
    extends MockBloc<AnnouncementEvent, AnnouncementState>
    implements AnnouncementBloc {}

class MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class MockBidRepository extends Mock implements BidRepository {}

class MockTrackingConsent extends Mock implements TrackingConsentCubit {}

class MockTripAudienceCubit extends MockCubit<TripAudienceState>
    implements TripAudienceCubit {}

class MockTripGroupCubit extends MockCubit<TripGroupState>
    implements TripGroupCubit {}

class _FakeContext extends Fake implements BuildContext {}

/// Écran ouvert : chemin complet et `extra`.
typedef AnswerPushedRoute = ({String location, Object? extra});

AnnouncementModel answerTrip({
  String status = 'ACTIVE',
  int pendingBidCount = 0,
  TripParcelsSummary? parcelsSummary,
  String? tripGroupId,
}) => AnnouncementModel(
  id: 'trip-1',
  travelerId: 'trav-1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 11, 12),
  availableKg: 20,
  totalKg: 20,
  pricePerKg: 7,
  status: status,
  pendingBidCount: pendingBidCount,
  parcelsSummary: parcelsSummary,
  tripGroupId: tripGroupId,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

BidModel answerBid(
  String id, {
  String status = 'PENDING',
  BidPaymentMethod method = BidPaymentMethod.stripe,
  String? senderName,
  String? category,
  String? description,
  double? weightKg = 3,
  double? net,
  String currency = 'EUR',
}) => BidModel(
  id: id,
  announcementId: 'trip-1',
  senderId: 'sender-$id',
  senderName: senderName ?? 'Expéditeur $id',
  weightKg: weightKg,
  contentCategory: category,
  description: description,
  totalAmountEur: net,
  currency: currency,
  status: status,
  paymentMethod: method,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// Demandes à traiter numérotées `r1`… `rN`, de « Expéditeur r1 »…
List<BidModel> answerRequests(
  int n, {
  BidPaymentMethod method = BidPaymentMethod.stripe,
}) => [
  for (var i = 1; i <= n; i++)
    answerBid('r$i', method: method, description: 'Contenu $i', net: 10.0 * i),
];

/// Blocs simulés de l'écran et de la réponse, pilotés par des flux.
class AnswerHarness {
  AnswerHarness() {
    annBloc = MockAnnouncementBloc();
    screenBids = MockBidBloc();
    answerBids = MockBidBloc();
    acceptance = MockBidAcceptanceBloc();
    repository = MockBidRepository();
    consent = MockTrackingConsent();
    backend = MockAnalyticsBackend();
  }

  late final MockAnnouncementBloc annBloc;
  late final MockBidBloc screenBids;
  late final MockBidBloc answerBids;
  late final MockBidAcceptanceBloc acceptance;
  late final MockBidRepository repository;
  late final MockTrackingConsent consent;
  late final MockAnalyticsBackend backend;

  final annStates = StreamController<AnnouncementState>.broadcast();
  final screenStates = StreamController<BidState>.broadcast();
  final answerStates = StreamController<BidState>.broadcast();
  final acceptanceStates = StreamController<acs.BidAcceptanceState>.broadcast();

  /// Événements reçus par chaque bloc simulé, dans l'ordre.
  final screenEvents = <BidEvent>[];
  final annEvents = <AnnouncementEvent>[];
  final answerEvents = <BidEvent>[];
  final acceptanceEvents = <ace.BidAcceptanceEvent>[];

  /// Prépare `getIt` et les fausses réponses, à appeler dans `setUp`.
  Future<void> setUp() async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    await getIt.reset();
    getIt
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<BidRepository>(repository)
      ..registerSingleton<TrackingConsentCubit>(consent);
    when(
      () => repository.previewCommissionAllocation(any()),
    ).thenAnswer((_) async => singleWalletPreview);
    when(() => consent.onParcelAccepted(any())).thenAnswer((_) async => false);
    when(() => screenBids.add(any())).thenAnswer(
      (i) => screenEvents.add(i.positionalArguments.first as BidEvent),
    );
    when(() => annBloc.add(any())).thenAnswer(
      (i) => annEvents.add(i.positionalArguments.first as AnnouncementEvent),
    );
    when(() => answerBids.add(any())).thenAnswer(
      (i) => answerEvents.add(i.positionalArguments.first as BidEvent),
    );
    when(() => acceptance.add(any())).thenAnswer(
      (i) => acceptanceEvents.add(
        i.positionalArguments.first as ace.BidAcceptanceEvent,
      ),
    );
    DonySnackbar.clearDedup();
  }

  Future<void> tearDown() async {
    await annStates.close();
    await screenStates.close();
    await answerStates.close();
    await acceptanceStates.close();
    await getIt.reset();
  }

  static void registerFallbacks() {
    registerFallbackValue(_FakeContext());
    registerFallbackValue(BidListRequested('fallback'));
    registerFallbackValue(AnnouncementDetailRequested('fallback'));
    registerFallbackValue(ace.BidAcceptRequested('fallback'));
  }

  /// Monte [body] sous les blocs de l'écran et le scope de réponse.
  /// [trip] et [bids] : états de départ de l'écran.
  Future<List<AnswerPushedRoute>> pump(
    WidgetTester tester, {
    required AnnouncementModel trip,
    required List<BidModel>? bids,
    required Widget Function(BuildContext context) body,
    Locale locale = const Locale('fr'),
    double textScale = 1,
    Size size = const Size(400, 1000),
    TripAudienceCubit? audience,
    TripGroupCubit? group,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(
      annBloc,
      annStates.stream,
      initialState: AnnouncementDetailLoaded(trip),
    );
    whenListen(
      screenBids,
      screenStates.stream,
      initialState: bids == null ? BidLoading() : BidListLoaded(bids),
    );
    whenListen(answerBids, answerStates.stream, initialState: BidInitial());
    whenListen(
      acceptance,
      acceptanceStates.stream,
      initialState: acs.BidAcceptanceInitial(),
    );
    final pushed = <AnswerPushedRoute>[];

    Widget stub(BuildContext context, GoRouterState state) {
      pushed.add((location: state.uri.toString(), extra: state.extra));
      return Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('back'),
            ),
            TextButton(
              onPressed: () => context.pop(true),
              child: const Text('back-true'),
            ),
          ],
        ),
      );
    }

    Widget screen(BuildContext context) => MultiBlocProvider(
      providers: [
        BlocProvider<AnnouncementBloc>.value(value: annBloc),
        BlocProvider<BidBloc>.value(value: screenBids),
        if (audience != null)
          BlocProvider<TripAudienceCubit>.value(value: audience),
        if (group != null) BlocProvider<TripGroupCubit>.value(value: group),
      ],
      child: TripBidAnswerScope(
        tripId: trip.id,
        bidBloc: answerBids,
        acceptanceBloc: acceptance,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(DonySpacing.lg),
            child: Builder(builder: body),
          ),
        ),
      ),
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, _) => screen(context)),
        GoRoute(path: '/bids/:bidId', builder: stub),
        GoRoute(path: '/announcements/:id/bids', builder: stub),
        GoRoute(path: '/announcements/:id/trip', builder: stub),
        GoRoute(path: '/payments/wallet/topup/method', builder: stub),
        GoRoute(path: '/payments/commission-method', builder: stub),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        routerConfig: router,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return pushed;
  }
}

/// Commission prise sur un seul portefeuille, dans la devise du colis :
/// aucune explication à donner avant d'accepter.
const singleWalletPreview = CommissionAllocationPreview(
  bidCurrency: 'EUR',
  commission: 2,
  covered: true,
  lines: [
    CommissionAllocationLine(currency: 'EUR', debitAmount: 2, coveredInBid: 2),
  ],
);

/// Commission répartie sur deux portefeuilles : la feuille d'explication
/// s'ouvre avant d'accepter.
const splitWalletPreview = CommissionAllocationPreview(
  bidCurrency: 'EUR',
  commission: 2,
  covered: true,
  lines: [
    CommissionAllocationLine(currency: 'EUR', debitAmount: 1, coveredInBid: 1),
    CommissionAllocationLine(
      currency: 'XOF',
      debitAmount: 656,
      coveredInBid: 1,
      rateOfTheDay: 655.957,
    ),
  ],
);
