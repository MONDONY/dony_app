import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_header.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// FLUTTER-9N : poussé depuis un colis, le Suivi offre un retour.
void main() {
  testWidgets('retour seulement quand le Suivi est poussé', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: SuiviHeader(onDark: false)),
        ),
        GoRoute(
          path: '/tracking/validate',
          builder: (_, _) => const Scaffold(body: SuiviHeader(onDark: false)),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('suivi-back')), findsNothing);

    unawaited(router.push('/tracking/validate'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('suivi-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('suivi-back')));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/');
  });
}
