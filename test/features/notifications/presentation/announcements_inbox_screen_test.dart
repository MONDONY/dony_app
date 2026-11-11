import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_bloc.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_event.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/presentation/announcements_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';

class _MockBloc extends Mock implements AnnouncementsInboxBloc {}

class _FakeEvent extends Fake implements AnnouncementsInboxEvent {}

NotificationModel _annonce({
  required String id,
  String title = 'Maintenance ce soir',
  bool read = false,
  String type = 'ADMIN_BROADCAST',
  String? deeplink,
}) => NotificationModel(
  id: id,
  type: type,
  deeplink: deeplink,
  category: 'annonce',
  title: title,
  body: 'Le service sera interrompu de 22 h à 23 h.',
  data: const {},
  read: read,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

void main() {
  late _MockBloc bloc;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    bloc = _MockBloc();
    when(() => bloc.close()).thenAnswer((_) async {});
    when(() => bloc.add(any())).thenReturn(null);
    if (getIt.isRegistered<AnnouncementsInboxBloc>()) {
      getIt.unregister<AnnouncementsInboxBloc>();
    }
    getIt.registerFactory<AnnouncementsInboxBloc>(() => bloc);
  });

  tearDown(() => getIt.unregister<AnnouncementsInboxBloc>());

  void stub(AnnouncementsInboxState state) {
    when(() => bloc.state).thenReturn(state);
    when(
      () => bloc.stream,
    ).thenAnswer((_) => Stream<AnnouncementsInboxState>.value(state));
  }

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      const MaterialApp(home: AnnouncementsInboxScreen()),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('ouverture : la liste est demandée au bloc', (tester) async {
    stub(const AnnouncementsInboxInitial());

    await pump(tester, settle: false);

    verify(
      () => bloc.add(any(that: isA<AnnouncementsInboxLoadRequested>())),
    ).called(1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Annonces Yadony'), findsOneWidget);
  });

  testWidgets('erreur : état dédié avec réessai', (tester) async {
    stub(const AnnouncementsInboxError(NetworkException('Hors ligne')));

    await pump(tester);
    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    verify(
      () => bloc.add(any(that: isA<AnnouncementsInboxLoadRequested>())),
    ).called(2);
  });

  testWidgets('aucune annonce : état vide', (tester) async {
    stub(const AnnouncementsInboxLoaded([]));

    await pump(tester);

    expect(find.text('Aucune annonce'), findsOneWidget);
  });

  testWidgets('les annonces sont listées sans icône, titre et corps bornés', (
    tester,
  ) async {
    stub(
      AnnouncementsInboxLoaded([
        _annonce(id: 'a'),
        _annonce(id: 'b', title: 'Nouvelles conditions', read: true),
      ]),
    );

    await pump(tester);

    expect(find.text('Maintenance ce soir'), findsOneWidget);
    expect(find.text('Nouvelles conditions'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Maintenance ce soir'));
    expect(title.maxLines, 1);
    final body = tester
        .widgetList<Text>(
          find.text('Le service sera interrompu de 22 h à 23 h.'),
        )
        .first;
    expect(body.maxLines, 2);
  });

  testWidgets('le tap marque l\'annonce lue', (tester) async {
    stub(AnnouncementsInboxLoaded([_annonce(id: 'a')]));

    await pump(tester);
    await tester.tap(find.text('Maintenance ce soir'));
    await tester.pump();

    verify(
      () => bloc.add(
        any(
          that: isA<AnnouncementsInboxMarkReadRequested>().having(
            (e) => e.id,
            'id',
            'a',
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('anglais : titre et état vide traduits', (tester) async {
    useEnglish();
    stub(const AnnouncementsInboxLoaded([]));

    await pump(tester);

    expect(find.text('Yadony announcements'), findsOneWidget);
    expect(find.text('No announcements'), findsOneWidget);
    expect(
      find.text('News and information from Yadony will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('anglais : erreur de chargement traduite', (tester) async {
    useEnglish();
    stub(const AnnouncementsInboxError(NetworkException('Hors ligne')));

    await pump(tester);

    expect(find.text('Loading error'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('navigation au tap', () {
    Future<List<String>> tapAndCollect(
      WidgetTester tester,
      NotificationModel a,
    ) async {
      stub(AnnouncementsInboxLoaded([a]));
      final visited = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const AnnouncementsInboxScreen(),
          ),
          for (final p in [
            '/profile/gp-pro',
            '/profile/tax-info',
            '/notifications/:id',
          ])
            GoRoute(
              path: p,
              builder: (_, state) {
                visited.add(state.uri.toString());
                return const Scaffold(body: Text('cible'));
              },
            ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maintenance ce soir'));
      await tester.pumpAndSettle();
      return visited;
    }

    testWidgets('GP_PRO_REVOKED avec deeplink ouvre /profile/gp-pro', (
      tester,
    ) async {
      final visited = await tapAndCollect(
        tester,
        _annonce(
          id: 'a',
          type: 'GP_PRO_REVOKED',
          deeplink: 'yadony://profile/gp-pro',
        ),
      );
      expect(visited, ['/profile/gp-pro']);
    });

    for (final type in ['GP_PRO_APPROVED', 'GP_PRO_REJECTED']) {
      testWidgets('$type sans deeplink passe par le resolver', (tester) async {
        final visited = await tapAndCollect(
          tester,
          _annonce(id: 'a', type: type),
        );
        expect(visited, ['/profile/gp-pro']);
      });
    }

    testWidgets('TAX_STATEMENT ouvre /profile/tax-info', (tester) async {
      final visited = await tapAndCollect(
        tester,
        _annonce(id: 'a', type: 'TAX_STATEMENT'),
      );
      expect(visited, ['/profile/tax-info']);
    });

    testWidgets('type inconnu : détail générique, lue quand même', (
      tester,
    ) async {
      final visited = await tapAndCollect(
        tester,
        _annonce(id: 'abc', type: 'PROMO'),
      );
      expect(visited, ['/notifications/abc']);
      verify(
        () => bloc.add(any(that: isA<AnnouncementsInboxMarkReadRequested>())),
      ).called(1);
    });

    testWidgets('deeplink vers une route inconnue : détail générique', (
      tester,
    ) async {
      final visited = await tapAndCollect(
        tester,
        _annonce(id: 'abc', type: 'PROMO', deeplink: 'yadony://nulle-part'),
      );
      expect(visited, ['/notifications/abc']);
    });
  });
}
