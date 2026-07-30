import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
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
import 'package:dony/features/package_request/bloc/package_request_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_analytics_backend.dart';

class _MockTravelerBidsBloc
    extends MockBloc<TravelerBidsEvent, TravelerBidsState>
    implements TravelerBidsBloc {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

// ContextualTutorialCard (contexte receivedRequests) lit HelpCenterBloc via
// context.select : sans ce provider, context.select lève
// ProviderNotFoundException dès le premier pump.
const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

late List<String> visited;

Future<void> _pump(
  WidgetTester tester, {
  required TravelerBidsState travelerBidsState,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  visited = [];

  final travelerBids = _MockTravelerBidsBloc();
  when(() => travelerBids.state).thenReturn(travelerBidsState);
  final bidBloc = _MockBidBloc();
  when(() => bidBloc.state).thenReturn(BidListLoaded(const []));
  final acceptance = _MockBidAcceptanceBloc();
  when(() => acceptance.state).thenReturn(acs.BidAcceptanceInitial());
  final packageRequests = _MockPackageRequestBloc();
  when(() => packageRequests.state).thenReturn(PackageRequestState());

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<TravelerBidsBloc>.value(value: travelerBids),
            BlocProvider<BidBloc>.value(value: bidBloc),
            BlocProvider<BidAcceptanceBloc>.value(value: acceptance),
            BlocProvider<PackageRequestBloc>.value(value: packageRequests),
            BlocProvider<HelpCenterBloc>(
              create: (_) => HelpCenterBloc(
                HelpCenterRepository(
                  const _StaticHelpCenterSource(_emptyHelpConfigJson),
                  fallbackJsonLoader: () async => _emptyHelpConfigJson,
                ),
                makeDisabledAnalytics(MockAnalyticsBackend()),
              )..add(const HelpCenterLoadRequested()),
            ),
          ],
          child: const DemandesScreenTesting(),
        ),
      ),
      GoRoute(
        path: '/trips/create',
        builder: (_, __) {
          visited.add('/trips/create');
          return const Scaffold(body: Text('Créer trajet'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
  );
  // Draine les timers d'animation (flutter_animate dans l'empty state / les
  // cartes) : sans ça le binding échoue sur un timer encore en vol.
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() {
    registerFallbackValue(const TravelerBidsRequested());
  });

  setUp(() {
    if (!getIt.isRegistered<AnalyticsService>()) {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    }
  });

  tearDown(() => getIt.reset());

  TravelerBidsLoaded loaded(List<BidModel> bids) => TravelerBidsLoaded(
    bids: bids,
    page: 0,
    hasMore: false,
    filter: TravelerBidFilter.aTraiter,
  );

  testWidgets('les deux volets du toggle sont présents', (tester) async {
    await _pump(tester, travelerBidsState: loaded(const []));

    expect(find.text('Reçues'), findsOneWidget);
    expect(find.text('Envoyées'), findsOneWidget);
  });

  testWidgets('le badge « à traiter » s\'affiche sur Reçues', (tester) async {
    await _pump(
      tester,
      travelerBidsState: loaded([
        _bid('b1', 'PENDING'),
        _bid('b2', 'PAYMENT_ESCROWED'),
        _bid('b3', 'ACCEPTED'),
      ]),
    );

    // 2 en attente d'une décision (PENDING + PAYMENT_ESCROWED), pas le 3e.
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('aucun badge quand rien à traiter', (tester) async {
    await _pump(tester, travelerBidsState: loaded([_bid('b1', 'ACCEPTED')]));

    expect(find.text('0'), findsNothing);
  });

  testWidgets('l\'état vide « À traiter » propose de publier un trajet', (
    tester,
  ) async {
    await _pump(tester, travelerBidsState: loaded(const []));

    final cta = find.text('Publier un trajet');
    expect(cta, findsOneWidget);

    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(visited, contains('/trips/create'));
  });

  testWidgets('le volet Reçues propose un champ de recherche', (tester) async {
    await _pump(tester, travelerBidsState: loaded([_bid('b1', 'PENDING')]));

    expect(
      find.widgetWithText(TextField, 'Expéditeur, n° de suivi…'),
      findsOneWidget,
    );
  });
}
