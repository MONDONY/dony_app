import 'package:dony/app/router.dart';
import 'package:dony/features/assistant/presentation/widgets/assistant_route_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // PosthogObserver (observers du routeur) lit WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('/assistant est une route du routeur de l’app', () {
    expect(assistantRouteExists(appRouter, '/assistant'), isTrue);
    expect(
      assistantRouteExists(appRouter, '/assistant?source=messages_header'),
      isTrue,
    );
  });

  test('les routes que l’assistant propose existent dans le routeur', () {
    expect(assistantRouteExists(appRouter, '/support'), isTrue);
    expect(assistantRouteExists(appRouter, '/support/tickets/abc'), isTrue);
    expect(assistantRouteExists(appRouter, '/route-inventee'), isFalse);
  });

  test('racines d’onglet dans le shell, fiches hors shell', () {
    expect(assistantRouteNeedsGo(appRouter, '/home'), isTrue);
    expect(assistantRouteNeedsGo(appRouter, '/messages'), isTrue);
    expect(assistantRouteNeedsGo(appRouter, '/profile'), isTrue);
    expect(assistantRouteNeedsGo(appRouter, '/support'), isFalse);
    expect(assistantRouteNeedsGo(appRouter, '/assistant'), isFalse);
  });

  test('routes à redirection de l’app (billets) : go', () {
    expect(assistantRouteNeedsGo(appRouter, '/flights/alerts'), isTrue);
    expect(assistantRouteNeedsGo(appRouter, '/flights'), isTrue);
  });
}
