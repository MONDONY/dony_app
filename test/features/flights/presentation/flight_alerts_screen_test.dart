import 'package:dony/core/di/injection.dart';
import 'package:dony/features/flights/bloc/flight_alerts_cubit.dart';
import 'package:dony/features/flights/data/models/flight_alert.dart';
import 'package:dony/features/flights/presentation/flight_alerts_screen.dart';
import 'package:dony/features/flights/presentation/widgets/flight_ui.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../bloc/flights_test_doubles.dart';

void main() {
  late MockFlightsRepository repository;

  setUp(() {
    repository = MockFlightsRepository();
    if (getIt.isRegistered<FlightAlertsCubit>()) {
      getIt.unregister<FlightAlertsCubit>();
    }
    getIt.registerFactory<FlightAlertsCubit>(
      () => FlightAlertsCubit(repository, silentAnalytics()),
    );
  });

  tearDown(() => getIt.unregister<FlightAlertsCubit>());

  testWidgets('liste : trajet, période, seuil et dernier prix', (tester) async {
    when(() => repository.alerts()).thenAnswer(
      (_) async => [
        FlightAlert(
          id: 'a1',
          originCode: 'PAR',
          destinationCode: 'ABJ',
          originLabel: 'Paris',
          destinationLabel: 'Abidjan',
          departureFrom: DateTime(2026, 12, 12),
          departureTo: DateTime(2026, 12, 31),
          returnFrom: DateTime(2027, 1, 2),
          returnTo: DateTime(2027, 1, 15),
          directOnly: false,
          maxPrice: 450,
          currency: 'EUR',
          active: true,
          lastSeenPrice: 431,
        ),
      ],
    );

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Mes alertes prix'), findsOneWidget);
    // Aller-retour : double flèche, comme dans l'écran Billets.
    expect(find.text('Paris ↔ Abidjan'), findsOneWidget);
    expect(
      find.textContaining('Départ du 12 déc. au 31 déc. 2026'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Retour du 2 janv. au 15 janv. 2027'),
      findsOneWidget,
    );
    expect(find.text('1 sur 10'), findsOneWidget);
    expect(find.byKey(const Key('flight-alerts-new')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('jour unique et sans période : libellés courts', (tester) async {
    when(() => repository.alerts()).thenAnswer(
      (_) async => [
        FlightAlert(
          id: 'a1',
          originCode: 'PAR',
          destinationCode: 'DKR',
          originLabel: 'Paris',
          destinationLabel: 'Dakar',
          departureFrom: DateTime(2026, 12, 23),
          departureTo: DateTime(2026, 12, 23),
          returnFrom: DateTime(2027, 1, 2),
          returnTo: DateTime(2027, 1, 2),
          directOnly: false,
          maxPrice: 450,
          currency: 'EUR',
          active: true,
        ),
        const FlightAlert(
          id: 'a2',
          originCode: 'PAR',
          destinationCode: 'BKO',
          originLabel: 'Paris',
          destinationLabel: 'Bamako',
          directOnly: false,
          maxPrice: 300,
          currency: 'EUR',
          active: true,
        ),
      ],
    );

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Départ le 23 déc. 2026 · Retour le 2 janv. 2027'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Départ à toutes dates · Aller simple'),
      findsOneWidget,
    );
    expect(find.textContaining('Toutes les dates à venir'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aucune alerte : état vide avec bouton de création', (
    tester,
  ) async {
    when(() => repository.alerts()).thenAnswer((_) async => const []);

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Aucune alerte prix'), findsOneWidget);
    // L'état vide porte déjà son bouton : pas de second bouton flottant.
    expect(find.byKey(const Key('flight-alerts-new')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chargement : squelettes, puis interrupteur Yadony', (
    tester,
  ) async {
    const alert = FlightAlert(
      id: 'a1',
      originCode: 'PAR',
      destinationCode: 'ABJ',
      directOnly: true,
      maxPrice: 450,
      currency: 'EUR',
      active: true,
    );
    when(() => repository.alerts()).thenAnswer((_) async => [alert]);
    when(
      () => repository.setAlertActive('a1', false),
    ).thenAnswer((_) async => alert.copyWith(active: false));

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    expect(find.byKey(const Key('flight-alerts-loading')), findsOneWidget);
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('flight-alert-switch-a1'));
    expect(tester.widget<FlightToggle>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<FlightToggle>(toggle).value, isFalse);
    verify(() => repository.setAlertActive('a1', false)).called(1);
  });

  testWidgets('premier chargement en échec : erreur puis réessayer', (
    tester,
  ) async {
    var calls = 0;
    when(() => repository.alerts()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return const [];
    });

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune alerte prix'), findsOneWidget);
  });

  testWidgets('état vide : le bouton ouvre la feuille de création', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    when(() => repository.alerts()).thenAnswer((_) async => const []);

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle alerte').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('flight-alert-submit')), findsOneWidget);
  });

  testWidgets('glisser supprime ; une bascule refusée affiche l\'erreur', (
    tester,
  ) async {
    final alerts = [
      for (final id in ['a1', 'a2'])
        FlightAlert(
          id: id,
          originCode: 'PAR',
          destinationCode: 'ABJ',
          directOnly: false,
          maxPrice: 450,
          currency: 'EUR',
          active: true,
        ),
    ];
    when(() => repository.alerts()).thenAnswer((_) async => alerts);
    when(() => repository.deleteAlert('a1')).thenAnswer((_) async {});
    when(
      () => repository.setAlertActive('a2', false),
    ).thenThrow(Exception('offline'));

    await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('2 sur 10'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('flight-alert-switch-a1')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    verify(() => repository.deleteAlert('a1')).called(1);
    expect(find.byKey(const Key('flight-alert-switch-a1')), findsNothing);

    await tester.tap(find.byKey(const Key('flight-alert-switch-a2')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('résultat de chaque alerte', () {
    FlightAlert alert(
      String id, {
      double? seen,
      int? count,
      bool active = true,
      DateTime? checkedAt,
      double max = 450,
    }) => FlightAlert(
      id: id,
      originCode: 'PAR',
      destinationCode: 'ABJ',
      originLabel: 'Paris',
      destinationLabel: 'Abidjan',
      directOnly: true,
      maxPrice: max,
      currency: 'EUR',
      active: active,
      lastSeenPrice: seen,
      lastCheckedAt: checkedAt,
      matchCount: count,
    );

    Finder text(String expected) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data?.replaceAll(RegExp('[\u00a0\u202f]'), ' ') == expected,
    );

    testWidgets('les quatre états, seuil dans les détails', (tester) async {
      tester.view.physicalSize = const Size(390, 1400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      when(() => repository.alerts()).thenAnswer(
        (_) async => [
          alert('hit', seen: 389, count: 3, checkedAt: twoHoursAgo),
          alert('above', seen: 512, count: 0, checkedAt: twoHoursAgo),
          alert('paused', seen: 300, count: 2, active: false),
          alert('pending'),
        ],
      );

      await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('flight-alert-result-hit')), findsOneWidget);
      expect(text('389 €'), findsOneWidget);
      expect(
        find.text('3 vols sous votre prix\nvérifiée il y a 2 h'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('flight-alert-see-hit')), findsOneWidget);

      expect(find.byKey(const Key('flight-alert-result-above')), findsOne);
      expect(text('512 €'), findsOneWidget);
      expect(
        text(
          'Meilleur prix du moment, encore au-dessus de 450 €\nvérifiée il y a 2 h',
        ),
        findsOneWidget,
      );

      expect(find.byKey(const Key('flight-alert-result-paused')), findsOne);
      expect(find.text('En pause : plus de vérification'), findsOneWidget);
      // Chaque état ouvre les vols : « Voir » vert sur le bloc vert, « Voir
      // les vols » neutre ailleurs.
      for (final id in ['hit', 'above', 'paused', 'pending']) {
        expect(find.byKey(Key('flight-alert-see-$id')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('flight-alert-see-hit')),
          matching: find.text('Voir'),
        ),
        findsOneWidget,
      );
      expect(find.text('Voir les vols'), findsNWidgets(3));

      expect(find.byKey(const Key('flight-alert-result-pending')), findsOne);
      expect(find.text('Pas encore vérifiée'), findsOneWidget);

      expect(
        find.textContaining('Vols directs seulement · max 450'),
        findsNWidgets(4),
      );
    });

    testWidgets('vérifiée sans aucun vol ; prix sous le seuil sans nombre', (
      tester,
    ) async {
      when(() => repository.alerts()).thenAnswer(
        (_) async => [
          alert('none', checkedAt: DateTime.now()),
          alert('old', seen: 400),
          alert('stale', seen: 300, count: 0, checkedAt: DateTime.now()),
        ],
      );

      await tester.pumpWidget(localizedApp(const FlightAlertsScreen()));
      await tester.pumpAndSettle();

      // Sans prix, et avec un dernier prix périmé (matchCount à 0) : aucun
      // prix affiché.
      expect(
        find.text("Aucun vol trouvé pour l'instant\nvérifiée à l'instant"),
        findsNWidgets(2),
      );
      expect(find.text('Sous votre prix'), findsOneWidget);
    });

    testWidgets('« Voir » ouvre les vols trouvés avec l\'alerte', (
      tester,
    ) async {
      final hit = alert('a1', seen: 389, count: 3);
      when(() => repository.alerts()).thenAnswer((_) async => [hit]);
      Object? extra;
      String? location;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const FlightAlertsScreen()),
          GoRoute(
            path: '/flights/alerts/:id/offers',
            builder: (_, state) {
              extra = state.extra;
              location = state.uri.toString();
              return const Scaffold(body: Text('vols trouvés'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(
          locale: AppL10n.fr,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('flight-alert-see-a1')));
      await tester.pumpAndSettle();

      expect(find.text('vols trouvés'), findsOneWidget);
      expect(location, '/flights/alerts/a1/offers');
      expect(extra, hit);
    });

    for (final (state, build, result) in [
      (
        'au-dessus du prix',
        () => alert('a1', seen: 512, count: 0, checkedAt: DateTime.now()),
        'above',
      ),
      ('en pause', () => alert('a1', seen: 300, active: false), 'paused'),
      ('pas encore vérifiée', () => alert('a1'), 'pending'),
    ]) {
      testWidgets('$state : « Voir les vols » et tout le bloc ouvrent', (
        tester,
      ) async {
        final a = build();
        when(() => repository.alerts()).thenAnswer((_) async => [a]);
        final opened = <Object?>[];
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const FlightAlertsScreen()),
            GoRoute(
              path: '/flights/alerts/:id/offers',
              builder: (context, state) {
                opened.add(state.extra);
                return Scaffold(
                  body: TextButton(
                    onPressed: context.pop,
                    child: const Text('vols de l\'alerte'),
                  ),
                );
              },
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            locale: AppL10n.fr,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('flight-alert-see-a1')));
        await tester.pumpAndSettle();
        expect(find.text('vols de l\'alerte'), findsOneWidget);

        await tester.tap(find.text('vols de l\'alerte'));
        await tester.pumpAndSettle();
        // Le texte du bloc, hors pilule, ouvre aussi.
        await tester.tapAt(
          tester.getTopLeft(find.byKey(Key('flight-alert-result-$result'))) +
              const Offset(16, 16),
        );
        await tester.pumpAndSettle();
        expect(find.text('vols de l\'alerte'), findsOneWidget);
        expect(opened, [a, a]);
      });
    }
  });
}
