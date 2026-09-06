import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/disputes/bloc/dispute_list_bloc.dart';
import 'package:dony/features/disputes/bloc/dispute_list_event.dart';
import 'package:dony/features/disputes/bloc/dispute_list_state.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';
import 'package:dony/features/disputes/presentation/dispute_list_screen.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _disputeHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "dispute_open",
      "title": "Ouvrir un litige",
      "description": "Comprendre quand et comment contester une remise.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["dispute"]
    }
  ]
}
''';

class MockDisputeListBloc extends MockBloc<DisputeListEvent, DisputeListState>
    implements DisputeListBloc {}

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

DisputeModel _dispute({
  String status = 'OPEN',
  bool refundFrozen = true,
  bool isBeneficiary = false,
}) => DisputeModel(
  id: 'd-$status',
  bidId: 'b1',
  type: 'SENDER_NO_SHOW_CONTESTED',
  status: status,
  refundFrozen: refundFrozen,
  createdAt: DateTime(2026, 7, 12),
  myRole: 'SENDER',
  otherPartyName: 'Awa K.',
  departureCity: 'Lyon',
  arrivalCity: 'Abidjan',
  departureCountryCode: 'FR',
  arrivalCountryCode: 'CI',
  tripDate: DateTime(2026, 6, 20),
  weightKg: 5,
  resolutionType: status == 'RESOLVED' ? 'GUARANTEE_PAID' : null,
  resolvedAt: status == 'RESOLVED' ? DateTime(2026, 6, 4) : null,
  resolutionNote: status == 'RESOLVED' ? 'No-show confirmé.' : null,
  guaranteeAmountCents: status == 'RESOLVED' ? 4000 : null,
  isBeneficiary: isBeneficiary,
);

late MockDisputeListBloc bloc;

Widget _harness({
  DisputeListState? state,
  String helpConfigJson = _emptyHelpConfigJson,
}) {
  bloc = MockDisputeListBloc();
  whenListen(
    bloc,
    const Stream<DisputeListState>.empty(),
    initialState: state ?? const DisputeListLoading(),
  );
  final router = GoRouter(
    initialLocation: '/disputes',
    routes: [
      GoRoute(
        path: '/disputes',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<DisputeListBloc>.value(value: bloc),
            BlocProvider<HelpCenterBloc>(
              create: (_) => HelpCenterBloc(
                HelpCenterRepository(
                  _StaticHelpCenterSource(helpConfigJson),
                  fallbackJsonLoader: () async => _emptyHelpConfigJson,
                ),
                makeDisabledAnalytics(MockAnalyticsBackend()),
              )..add(const HelpCenterLoadRequested()),
            ),
          ],
          child: const DisputeListScreen(),
        ),
      ),
      GoRoute(
        path: '/disputes/detail',
        builder: (_, _) => const Scaffold(body: Text('DetailStub')),
      ),
      GoRoute(
        path: '/support',
        builder: (_, _) => const Scaffold(body: Text('SupportStub')),
      ),
      GoRoute(
        path: '/profile/help/tutorial/:tutorialId',
        builder: (_, state) => Scaffold(
          body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('liste : card avec type, statut, corridor, autre partie', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        state: DisputeListLoaded([_dispute(), _dispute(status: 'RESOLVED')]),
      ),
    );
    await tester.pump();
    // Drain les animations flutter_animate (stagger fadeIn) avant assertions
    // pour éviter un Timer en vol au tearDown du test.
    await tester.pumpAndSettle();

    expect(find.text("Contestation d'absence"), findsNWidgets(2));
    expect(find.text('En instruction'), findsOneWidget);
    expect(find.text('Résolu'), findsOneWidget);
    expect(find.textContaining('Lyon'), findsNWidgets(2));
    expect(find.textContaining('Voyageur : Awa K.'), findsNWidgets(2));
  });

  testWidgets('bandeau gel visible seulement si refundFrozen && OPEN', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        state: DisputeListLoaded([
          _dispute(),
          _dispute(status: 'RESOLVED', refundFrozen: false),
        ]),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Remboursement gelé'), findsOneWidget);
  });

  testWidgets('tap card → push détail', (tester) async {
    await tester.pumpWidget(_harness(state: DisputeListLoaded([_dispute()])));
    await tester.pump();
    await tester.tap(find.text("Contestation d'absence"));
    await tester.pumpAndSettle();
    expect(find.text('DetailStub'), findsOneWidget);
  });

  testWidgets('état vide pédagogique + CTA support', (tester) async {
    await tester.pumpWidget(_harness(state: const DisputeListLoaded([])));
    await tester.pump();
    expect(find.text('Aucun litige'), findsOneWidget);
    await tester.tap(find.text('Un problème avec un envoi ?'));
    await tester.pumpAndSettle();
    expect(find.text('SupportStub'), findsOneWidget);
  });

  testWidgets(
    'affiche la carte tutoriel litige au-dessus de la liste et navigue au tap',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          state: DisputeListLoaded([_dispute()]),
          helpConfigJson: _disputeHelpConfigJson,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Besoin d\'aide ? Voir le tutoriel'), findsOneWidget);

      await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
      await tester.pumpAndSettle();

      expect(find.text('TutorialStub:dispute_open'), findsOneWidget);
    },
  );

  testWidgets('erreur → Réessayer redispatch', (tester) async {
    await tester.pumpWidget(
      _harness(
        state: const DisputeListError(
          NetworkException('Erreur', code: 'network-error'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(const DisputesLoadRequested())).called(1);
  });
}
