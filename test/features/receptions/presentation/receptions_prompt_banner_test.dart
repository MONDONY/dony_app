import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/receptions/bloc/receptions_prompt_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/receptions/data/receptions_prompt_store.dart';
import 'package:dony/features/receptions/data/repositories/reception_repository.dart';
import 'package:dony/features/receptions/presentation/widgets/receptions_prompt_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ReceptionRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MemoryStore implements ReceptionsPromptStore {
  final Set<String> ids = {};

  @override
  Set<String> dismissed() => ids;

  @override
  Future<void> dismiss(Iterable<String> bidIds) async => ids.addAll(bidIds);
}

const _awa = Reception(
  bidId: 'p1',
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
  senderFirstName: 'Awa',
);
const _other = Reception(
  bidId: 'p2',
  linkStatus: 'PENDING',
  bidStatus: 'ACCEPTED',
);

void main() {
  late _MockRepo repo;
  late _MockAnalytics analytics;
  late _MemoryStore store;

  setUp(() {
    repo = _MockRepo();
    analytics = _MockAnalytics();
    store = _MemoryStore();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  Future<ReceptionsPromptCubit> pump(
    WidgetTester tester,
    List<Reception> receptions,
  ) async {
    when(() => repo.getReceptions()).thenAnswer((_) async => receptions);
    final cubit = ReceptionsPromptCubit(repo, store, analytics);
    addTearDown(cubit.close);
    await cubit.loadFor('u1');
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(body: ReceptionsPromptBanner(cubit: cubit)),
        ),
        GoRoute(
          path: '/receptions/:bidId',
          builder: (_, state) =>
              Text('reception ${state.pathParameters['bidId']}'),
        ),
        GoRoute(
          path: '/tracking',
          builder: (_, state) =>
              Text('suivi ${state.uri.queryParameters['segment']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        locale: AppL10n.fr,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('un colis : prénom de l\'expéditeur, tap → son écran', (
    tester,
  ) async {
    await pump(tester, [_awa]);
    expect(find.text('Awa vous envoie un colis'), findsOneWidget);
    expect(find.text("Confirmez qu'il est bien pour vous."), findsOneWidget);

    await tester.tap(find.byKey(const Key('receptions-prompt')));
    await tester.pumpAndSettle();
    expect(find.text('reception p1'), findsOneWidget);
  });

  testWidgets('plusieurs colis : tap → Suivi sur Réceptions', (tester) async {
    await pump(tester, [_awa, _other]);
    expect(find.text('2 colis vous attendent'), findsOneWidget);

    await tester.tap(find.byKey(const Key('receptions-prompt')));
    await tester.pumpAndSettle();
    expect(find.text('suivi receptions'), findsOneWidget);
  });

  testWidgets('sans prénom : « Un colis vous attend »', (tester) async {
    await pump(tester, [_other]);
    expect(find.text('Un colis vous attend'), findsOneWidget);
  });

  testWidgets('aucun colis à confirmer : rien', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(const Key('receptions-prompt')), findsNothing);
  });

  testWidgets('croix : disparaît et mémorisé', (tester) async {
    await pump(tester, [_awa]);
    await tester.tap(find.byKey(const Key('receptions-prompt-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receptions-prompt')), findsNothing);
    expect(store.ids, {'p1'});
  });
}
