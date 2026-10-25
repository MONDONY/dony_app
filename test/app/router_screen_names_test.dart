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

  test('écran d\'attente mobile money du supplément : nommé, et déclaré '
      'avant /bids/:bidId', () {
    const supplementPath =
        '/bids/:bidId/supplements/:supplementId/mobile-money/awaiting';
    final ordered = <GoRoute>[];
    void flatten(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute) {
          ordered.add(route);
          flatten(route.routes);
        } else if (route is StatefulShellRoute) {
          for (final branch in route.branches) {
            flatten(branch.routes);
          }
        } else if (route is ShellRoute) {
          flatten(route.routes);
        }
      }
    }

    flatten(appRouter.configuration.routes);
    final supplement = ordered.indexWhere((r) => r.path == supplementPath);
    final detail = ordered.indexWhere((r) => r.path == '/bids/:bidId');
    expect(supplement, isNot(-1));
    expect(ordered[supplement].name, supplementPath);
    expect(supplement, lessThan(detail));
  });

  test('écran d\'attente mobile money de la modification : nommé, et déclaré '
      'avant /bids/:bidId', () {
    const amendmentPath =
        '/bids/:bidId/amendments/:amendmentId/mobile-money/awaiting';
    final ordered = <GoRoute>[];
    void flatten(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute) {
          ordered.add(route);
          flatten(route.routes);
        } else if (route is StatefulShellRoute) {
          for (final branch in route.branches) {
            flatten(branch.routes);
          }
        } else if (route is ShellRoute) {
          flatten(route.routes);
        }
      }
    }

    flatten(appRouter.configuration.routes);
    final amendment = ordered.indexWhere((r) => r.path == amendmentPath);
    final detail = ordered.indexWhere((r) => r.path == '/bids/:bidId');
    expect(amendment, isNot(-1));
    expect(ordered[amendment].name, amendmentPath);
    expect(amendment, lessThan(detail));
  });
}
