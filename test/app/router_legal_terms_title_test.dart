// `/legal/terms` monte `LegalWebViewScreen`, qui instancie un vrai
// `WebViewController` (canal de plateforme) dès `initState` : on ne peut donc
// pas pumper cet écran dans un test widget classique. On appelle directement
// le `builder` de la route (comme `router_screen_names_test.dart` parcourt
// `appRouter.configuration.routes`, et comme `router_auth_redirect_test.dart`
// fabrique un `GoRouterState` synthétique) et on vérifie le champ `title` du
// widget construit, sans le pumper.
import 'package:dony/app/router.dart';
import 'package:dony/features/settings/presentation/screens/legal_web_view_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/l10n_test_helpers.dart';

GoRoute? _findRoute(List<RouteBase> routes, String path) {
  for (final route in routes) {
    if (route is GoRoute) {
      if (route.path == path) return route;
      final nested = _findRoute(route.routes, path);
      if (nested != null) return nested;
    } else if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        final found = _findRoute(branch.routes, path);
        if (found != null) return found;
      }
    } else if (route is ShellRoute) {
      final found = _findRoute(route.routes, path);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  testWidgets('/legal/terms affiche « Terms of Use » en anglais', (
    tester,
  ) async {
    final route = _findRoute(appRouter.configuration.routes, '/legal/terms');
    expect(route, isNotNull, reason: 'route /legal/terms introuvable');

    late BuildContext ctx;
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
        locale: AppL10n.en,
      ),
    );

    final state = GoRouterState(
      appRouter.configuration,
      uri: Uri.parse('/legal/terms'),
      matchedLocation: '/legal/terms',
      fullPath: '/legal/terms',
      pathParameters: const {},
      pageKey: const ValueKey('/legal/terms'),
    );

    final widget = route!.builder!(ctx, state);

    expect(widget, isA<LegalWebViewScreen>());
    expect((widget as LegalWebViewScreen).title, 'Terms of Use');
  });
}
