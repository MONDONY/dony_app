import 'package:dony/app/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// PosthogObserver lit `route.settings.name`, que go_router remplit avec
/// `state.name ?? state.path`. Pour une route imbriquée, `state.path` est le
/// segment relatif (`preferences`, `new`, `:id`) : le `$screen` PostHog perdait
/// son parent et `new` / `:id` devenaient ambigus (adresses ? destinataires ?).
/// Chaque route imbriquée porte donc un `name` égal à son chemin complet.
void main() {
  // PosthogObserver (observers du routeur) lit WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chaque route imbriquée est nommée par son chemin complet', () {
    final missing = <String>[];
    final names = <String, int>{};

    void visit(List<RouteBase> routes, String parent) {
      for (final route in routes) {
        if (route is GoRoute) {
          final full = route.path.startsWith('/')
              ? route.path
              : '${parent == '/' ? '' : parent}/${route.path}';
          if (!route.path.startsWith('/') && route.name != full) {
            missing.add('$full (name: ${route.name})');
          }
          if (route.name != null) {
            names.update(route.name!, (n) => n + 1, ifAbsent: () => 1);
          }
          visit(route.routes, full);
        } else if (route is StatefulShellRoute) {
          for (final branch in route.branches) {
            visit(branch.routes, parent);
          }
        } else if (route is ShellRoute) {
          visit(route.routes, parent);
        }
      }
    }

    visit(appRouter.configuration.routes, '/');

    expect(missing, isEmpty, reason: 'routes imbriquées sans name complet');
    expect(
      names.entries.where((e) => e.value > 1).map((e) => e.key),
      isEmpty,
      reason: 'un name de route doit être unique',
    );
  });
}
