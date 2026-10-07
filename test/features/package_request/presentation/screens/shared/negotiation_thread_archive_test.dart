import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/negotiation_repository.dart';
import 'package:dony/features/package_request/presentation/screens/shared/negotiation_thread_screen.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource();

  @override
  String get activatedJson => _emptyHelpConfigJson;

  @override
  Future<String?> fetchAndActivate() async => _emptyHelpConfigJson;
}

class _MockNegotiationBloc extends MockBloc<NegotiationEvent, NegotiationState>
    implements NegotiationBloc {}

class _MockRepo extends Mock implements NegotiationRepository {}

NegotiationThread _thread({
  NegotiationThreadStatus status = NegotiationThreadStatus.expired,
  bool archived = false,
}) => NegotiationThread(
  id: 't-1',
  packageRequestId: 'pr-1',
  travelerId: 'tr-1',
  travelerTravelDate: DateTime(2026, 6, 15),
  travelerAvailableKg: 10,
  status: status,
  currentPriceEur: 50,
  roundsCount: 1,
  lastActivityAt: DateTime(2026, 5, 10),
  createdAt: DateTime(2026, 5, 10),
  messages: const [],
  travelerName: 'Fatou',
  archived: archived,
);

/// Archiver / supprimer un fil de demande terminé depuis son écran de détail
/// (FLUTTER-EJ, yadony-back #423).
void main() {
  late _MockNegotiationBloc bloc;
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(const NegotiationFetchRequested('t-1'));
  });

  setUp(() {
    DonySnackbar.clearDedup();
    bloc = _MockNegotiationBloc();
    repo = _MockRepo();
    when(() => repo.findMine()).thenAnswer((_) async => []);
    if (getIt.isRegistered<NegotiationBloc>()) {
      getIt.unregister<NegotiationBloc>();
    }
    getIt.registerFactory<NegotiationBloc>(() => bloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<NegotiationBloc>()) {
      await getIt.unregister<NegotiationBloc>();
    }
    if (getIt.isRegistered<NegotiationListBloc>()) {
      await getIt.unregister<NegotiationListBloc>();
    }
  });

  /// Le fil est poussé par-dessus une liste factice, comme depuis « Discussions
  /// de prix » : le retour à la liste se voit.
  Future<void> pump(WidgetTester tester, NegotiationThread thread) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final listBloc = NegotiationListBloc(repo);
    addTearDown(listBloc.close);
    getIt.registerSingleton<NegotiationListBloc>(listBloc);
    whenListen(
      bloc,
      const Stream<NegotiationState>.empty(),
      initialState: NegotiationLoaded(thread),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (inner) => TextButton(
                onPressed: () => inner.push('/negotiations/t-1'),
                child: const Text('ListeStub'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/negotiations/:id',
          builder: (_, _) =>
              const NegotiationThreadScreen(threadId: 't-1', viewerUserId: 's'),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider<HelpCenterBloc>(
        create: (_) => HelpCenterBloc(
          HelpCenterRepository(
            const _StaticHelpCenterSource(),
            fallbackJsonLoader: () async => _emptyHelpConfigJson,
          ),
          makeDisabledAnalytics(MockAnalyticsBackend()),
        )..add(const HelpCenterLoadRequested()),
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ListeStub'));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nego-archive-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('fil en cours : aucune action d\'archivage', (tester) async {
    await pump(tester, _thread(status: NegotiationThreadStatus.open));
    expect(find.byKey(const Key('nego-archive-menu')), findsNothing);
  });

  testWidgets('Archiver : appel serveur, message, retour à la liste', (
    tester,
  ) async {
    when(() => repo.archive('t-1')).thenAnswer((_) async {});
    await pump(tester, _thread());

    await openMenu(tester);
    expect(find.text('Archiver'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    verify(() => repo.archive('t-1')).called(1);
    expect(find.text('Discussion archivée'), findsOneWidget);
    expect(find.text('ListeStub'), findsOneWidget);
  });

  testWidgets('fil archivé : « Désarchiver »', (tester) async {
    when(() => repo.unarchive('t-1')).thenAnswer((_) async {});
    await pump(tester, _thread(archived: true));

    await openMenu(tester);
    await tester.tap(find.text('Désarchiver'));
    await tester.pumpAndSettle();

    verify(() => repo.unarchive('t-1')).called(1);
    expect(find.text('Discussion désarchivée'), findsOneWidget);
  });

  testWidgets('Supprimer : confirmation puis retour à la liste', (
    tester,
  ) async {
    when(() => repo.delete('t-1')).thenAnswer((_) async {});
    await pump(tester, _thread());

    await openMenu(tester);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer la discussion ?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nego-delete-cancel')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.delete(any()));

    await openMenu(tester);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nego-delete-confirm')));
    await tester.pumpAndSettle();

    verify(() => repo.delete('t-1')).called(1);
    expect(find.text('Discussion supprimée'), findsOneWidget);
    expect(find.text('ListeStub'), findsOneWidget);
  });

  testWidgets('409 : on reste sur le fil, « Discussion encore en cours »', (
    tester,
  ) async {
    when(
      () => repo.archive('t-1'),
    ).thenThrow(const ConflictException('x', code: kNegotiationStillOpenCode));
    await pump(tester, _thread());

    await openMenu(tester);
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    expect(find.text('Discussion encore en cours'), findsOneWidget);
    expect(find.text('ListeStub'), findsNothing);
  });

  testWidgets('fil retiré (404 métier) : retour à la liste sans message', (
    tester,
  ) async {
    when(
      () => repo.delete('t-1'),
    ).thenThrow(const NotFoundException(apiCode: 'thread/not-found'));
    await pump(tester, _thread());

    await openMenu(tester);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nego-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('ListeStub'), findsOneWidget);
  });

  testWidgets('backend ancien (405) : message, on reste sur le fil', (
    tester,
  ) async {
    when(
      () => repo.archive('t-1'),
    ).thenThrow(const NetworkException('x', code: '405'));
    await pump(tester, _thread());

    await openMenu(tester);
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Cette action n'est pas encore disponible. Réessayez plus tard.",
      ),
      findsOneWidget,
    );
    expect(find.text('ListeStub'), findsNothing);
  });

  testWidgets('échec réseau : message d\'erreur, on reste sur le fil', (
    tester,
  ) async {
    when(() => repo.archive('t-1')).thenThrow(const OfflineException());
    await pump(tester, _thread());

    await openMenu(tester);
    await tester.tap(find.text('Archiver'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('ListeStub'), findsNothing);
  });
}
