import 'package:dony/app/router.dart';
import 'package:dony/core/config/flights_flag.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockState extends Mock implements GoRouterState {}

/// Billets d'avion et statistiques : deux sous-pages de la branche Activités,
/// la barre d'onglets revenue à cinq branches, `/flights` toujours valide.
void main() {
  // PosthogObserver (observers du routeur) lit WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(resetFlightsFlagForTest);

  StatefulShellRoute shell() =>
      appRouter.configuration.routes.whereType<StatefulShellRoute>().single;

  GoRoute topLevel(String path) => appRouter.configuration.routes
      .whereType<GoRoute>()
      .singleWhere((r) => r.path == path);

  GoRoute activitesChild(String path) {
    final activites = shell().branches[1].routes.single as GoRoute;
    expect(activites.path, '/announcements');
    return activites.routes.whereType<GoRoute>().singleWhere(
      (r) => r.path == path,
    );
  }

  testWidgets('cinq branches, dans l\'ordre de la barre d\'onglets', (
    tester,
  ) async {
    final roots = shell().branches
        .map((b) => (b.routes.single as GoRoute).path)
        .toList();
    expect(roots, [
      '/home',
      '/announcements',
      '/tracking',
      '/messages',
      '/profile',
    ]);
  });

  testWidgets('/flights renvoie sur l\'écran Billets d\'Activités', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    final redirect = topLevel('/flights').redirect!;
    expect(await redirect(context, _MockState()), '/announcements/flights');
  });

  testWidgets('Billets et statistiques, nommés par leur chemin complet', (
    tester,
  ) async {
    expect(activitesChild('flights').name, '/announcements/flights');
    expect(activitesChild('stats').name, '/announcements/stats');
  });

  testWidgets('écran Billets : ouvert si le flag est allumé, sinon accueil', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    final redirect = activitesChild('flights').redirect!;
    markFlightsFlagLoaded();

    expect(await redirect(context, _MockState()), '/home');

    setFlightsEnabled(true);
    expect(await redirect(context, _MockState()), isNull);
  });
}
