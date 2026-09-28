import 'package:dony/app/router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockContext extends Mock implements BuildContext {}

class _MockState extends Mock implements GoRouterState {}

/// La recherche et le hub de scan vivent désormais dans l'onglet Suivi : les
/// anciens chemins (liens et notifications déjà émis) y mènent avec le mode
/// correspondant.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GoRoute find(String path) {
    GoRoute? found;
    void visit(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute && route.path == path) found = route;
        if (route is StatefulShellRoute) {
          for (final branch in route.branches) {
            visit(branch.routes);
          }
        } else if (route is ShellRouteBase || route is GoRoute) {
          visit(route.routes);
        }
      }
    }

    visit(appRouter.configuration.routes);
    return found!;
  }

  test('/tracking/search → onglet Suivi, mode Suivre', () async {
    final redirect = find('/tracking/search').redirect!;
    expect(
      await redirect(_MockContext(), _MockState()),
      '/tracking?mode=suivre',
    );
  });

  test('/tracking/scan-hub → onglet Suivi, mode Valider', () async {
    final redirect = find('/tracking/scan-hub').redirect!;
    expect(
      await redirect(_MockContext(), _MockState()),
      '/tracking?mode=valider',
    );
  });
}
