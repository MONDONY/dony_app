import 'dart:async';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget host({required VoidCallback onCta, VoidCallback? onClose}) =>
      MaterialApp(
        theme: AppTheme.light,
        home: DonySuccessScreen(
          mascotteType: DonyMascotteType.securise,
          title: 'Envoi réservé !',
          subtitle: 'Ton paiement est sécurisé.',
          ctaLabel: 'Voir mes envois',
          onCta: onCta,
          onClose: onClose,
        ),
      );

  /// Harness GoRouter — nécessaire pour tester la navigation par défaut vers
  /// `/home` (le widget appelle `GoRouter.of(context)` quand `onClose` est null).
  Widget hostWithRouter({required VoidCallback onCta}) {
    final router = GoRouter(
      initialLocation: '/success',
      routes: [
        GoRoute(
          path: '/success',
          builder: (context, state) => DonySuccessScreen(
            mascotteType: DonyMascotteType.securise,
            title: 'Envoi réservé !',
            subtitle: 'Ton paiement est sécurisé.',
            ctaLabel: 'Voir mes envois',
            onCta: onCta,
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home stub')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light);
  }

  testWidgets('affiche titre, sous-titre et label du CTA', (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Envoi réservé !'), findsOneWidget);
    expect(find.text('Ton paiement est sécurisé.'), findsOneWidget);
    expect(find.text('Voir mes envois'), findsOneWidget);
  });

  testWidgets('tap sur le CTA appelle onCta exactement une fois', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(host(onCta: () => callCount++));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(DonyButton));
    await tester.pump();

    expect(callCount, 1);
  });

  testWidgets(
    'pas d\'auto-navigation : le CTA reste visible après 5 secondes',
    (tester) async {
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Voir mes envois'), findsOneWidget);
    },
  );

  testWidgets('affiche le bouton fermer (x)', (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  testWidgets(
    'tap sur le bouton fermer appelle onClose exactement une fois quand fourni',
    (tester) async {
      var callCount = 0;
      await tester.pumpWidget(host(onCta: () {}, onClose: () => callCount++));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();

      expect(callCount, 1);
    },
  );

  testWidgets('sans onClose, tap sur fermer navigue vers /home', (
    tester,
  ) async {
    await tester.pumpWidget(hostWithRouter(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets('un retour arrière système (back gesture/bouton) est ignoré : '
      'l\'écran de succès reste affiché', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Formulaire sous-jacent')),
      ),
    );
    await tester.pump();

    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => DonySuccessScreen(
            mascotteType: DonyMascotteType.securise,
            title: 'Envoi réservé !',
            subtitle: 'Ton paiement est sécurisé.',
            ctaLabel: 'Voir mes envois',
            onCta: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Envoi réservé !'), findsOneWidget);

    // Simule un retour arrière système (geste iOS / bouton Android).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Envoi réservé !'), findsOneWidget);
    expect(find.text('Formulaire sous-jacent'), findsNothing);
  });
}
