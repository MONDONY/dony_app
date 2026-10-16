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
}
