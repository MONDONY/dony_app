import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_chip.dart';
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
import 'package:dony/features/matching/data/models/traveler_bids_page.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/matching/presentation/screens/demandes_screen.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
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

// Onglet d'ouverture de l'écran « Demandes » : le vrai TravelerBidsBloc
// (singleton de getIt, comme en production) derrière un dépôt simulé.

class _MockBidRepository extends Mock implements BidRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockBidBloc extends MockBloc<BidEvent, BidState> implements BidBloc {}

class _MockBidAcceptanceBloc
    extends MockBloc<ace.BidAcceptanceEvent, acs.BidAcceptanceState>
    implements BidAcceptanceBloc {}

class _MockPackageRequestBloc
    extends MockBloc<PackageRequestEvent, PackageRequestState>
    implements PackageRequestBloc {}

class _MockNegotiationListBloc
    extends MockBloc<NegotiationListEvent, NegotiationListState>
    implements NegotiationListBloc {}

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

BidModel _bid(String id, String status) => BidModel(
  id: id,
  announcementId: 'a1',
  senderId: 's1',
  weightKg: 5,
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

TravelerBidsPage _page(List<BidModel> bids) =>
    TravelerBidsPage(content: bids, page: 0, isLast: true);

void main() {
  late _MockBidRepository repository;

  /// Singleton instancié paresseusement, donc dans la zone du test : créé
  /// dans `setUp`, ses futures échapperaient au temps simulé de `pump`.
  TravelerBidsBloc bloc() => getIt<TravelerBidsBloc>();

  /// Réponses successives du dépôt : une page prête ou un Completer qui
  /// laisse le chargement en vol.
  late List<Object> responses;

  setUp(() {
    repository = _MockBidRepository();
    responses = [];
    var call = 0;
    when(
      () => repository.getTravelerBids(
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) {
      final r =
          responses[call < responses.length ? call : responses.length - 1];
      call++;
      return r is Completer<TravelerBidsPage>
          ? r.future
          : Future.value(r as TravelerBidsPage);
    });

    final analytics = _MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerLazySingleton<AnalyticsService>(() => analytics);

    getIt.registerLazySingleton<TravelerBidsBloc>(
      () => TravelerBidsBloc(repository, analytics),
      dispose: (b) => b.close(),
    );
    getIt.registerFactory<BidBloc>(() {
      final b = _MockBidBloc();
      when(() => b.state).thenReturn(BidListLoaded(const []));
      return b;
    });
    getIt.registerFactory<BidAcceptanceBloc>(() {
      final b = _MockBidAcceptanceBloc();
      when(() => b.state).thenReturn(acs.BidAcceptanceInitial());
      return b;
    });
  });

  tearDown(() => getIt.reset());

  Future<void> pumpScreen(WidgetTester tester, {String? focusBidId}) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final packageRequests = _MockPackageRequestBloc();
    when(() => packageRequests.state).thenReturn(PackageRequestState());
    final negotiations = _MockNegotiationListBloc();
    when(() => negotiations.state).thenReturn(NegotiationListState());

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<PackageRequestBloc>.value(value: packageRequests),
              BlocProvider<NegotiationListBloc>.value(value: negotiations),
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
            child: DemandesScreen(focusBidId: focusBidId),
          ),
        ),
        GoRoute(
          path: '/bids/:bidId',
          builder: (_, _) => const Scaffold(body: Text('Détail demande')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    // Deux passes : la liste arrive pendant la première, la seconde draine
    // les animations (flutter_animate) de l'état vide qu'elle fait monter.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  TravelerBidFilter selectedChip(WidgetTester tester) {
    for (final f in TravelerBidFilter.values) {
      final chip = tester.widget<DonyChip>(
        find.byKey(Key('demandes-filter-${f.name}'), skipOffstage: false),
      );
      if (chip.selected) return f;
    }
    fail('aucune pastille sélectionnée');
  }

  /// Le singleton a déjà une liste (hub, onglet Activités) : l'écran s'ouvre
  /// dessus pendant que son propre rechargement est en vol.
  Future<Completer<TravelerBidsPage>> seedStaleThenHold(
    WidgetTester tester,
    List<BidModel> stale,
  ) async {
    final pending = Completer<TravelerBidsPage>();
    responses = [_page(stale), pending];
    bloc().add(const TravelerBidsRequested());
    await tester.pump();
    expect(bloc().state, isA<TravelerBidsLoaded>());
    return pending;
  }

  testWidgets('« À traiter » vide : ouvre sur le premier onglet non vide', (
    tester,
  ) async {
    responses = [
      _page([_bid('b1', 'ACCEPTED'), _bid('b2', 'NO_SHOW')]),
    ];

    await pumpScreen(tester);

    expect(selectedChip(tester), TravelerBidFilter.acceptees);
    expect(find.text('Acceptées (1)'), findsOneWidget);
  });

  testWidgets('seules des demandes terminées : ouvre sur « Terminées »', (
    tester,
  ) async {
    responses = [
      _page([_bid('b1', 'NO_SHOW')]),
    ];

    await pumpScreen(tester);

    expect(selectedChip(tester), TravelerBidFilter.terminees);
  });

  testWidgets('tout est vide : reste sur « À traiter »', (tester) async {
    responses = [_page(const [])];

    await pumpScreen(tester);

    expect(selectedChip(tester), TravelerBidFilter.aTraiter);
  });

  testWidgets('pendant le chargement : aucune bascule, décision au retour', (
    tester,
  ) async {
    final pending = await seedStaleThenHold(tester, const []);

    await pumpScreen(tester);
    expect(selectedChip(tester), TravelerBidFilter.aTraiter);

    pending.complete(_page([_bid('b1', 'ACCEPTED')]));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(selectedChip(tester), TravelerBidFilter.acceptees);
  });

  testWidgets('onglet choisi par l’utilisateur : jamais écrasé', (
    tester,
  ) async {
    final pending = await seedStaleThenHold(tester, const []);
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('demandes-filter-terminees')));
    await tester.pump();
    expect(selectedChip(tester), TravelerBidFilter.terminees);

    pending.complete(_page([_bid('b1', 'ACCEPTED')]));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(selectedChip(tester), TravelerBidFilter.terminees);
  });

  testWidgets('onglet imposé par la notification : « À traiter » respecté', (
    tester,
  ) async {
    responses = [
      _page([_bid('b1', 'ACCEPTED')]),
    ];

    await pumpScreen(
      tester,
      focusBidId: '11111111-2222-3333-4444-555555555555',
    );
    await tester.pumpAndSettle();

    expect(bloc().state, isA<TravelerBidsLoaded>());
    expect(
      (bloc().state as TravelerBidsLoaded).filter,
      TravelerBidFilter.aTraiter,
    );
  });
}
