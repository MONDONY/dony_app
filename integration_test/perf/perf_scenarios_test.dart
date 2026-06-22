// integration_test/perf/perf_scenarios_test.dart
//
// Scénarios de performance UI A1–A7.
//
// Chaque scénario :
//   1. bootToHome()           — démarre l'app et s'assure d'être sur le home
//   2. navigation éventuelle  — via appRouter.go()
//   3. traceAction(geste)     — enregistre la timeline Flutter
//   4. dumpNetwork(scenario)  — écrit build/perf/network-<scenario>.json
//
// Le driver (test_driver/perf_driver.dart) lit binding.reportData et écrit :
//   build/perf/<scenario>.timeline.json
//   build/perf/<scenario>.summary.json
//
// Shape agréée test ↔ driver :
//   binding.reportData[scenario] = { 'timeline': {...}, 'summary': {...} }
// Le driver cast la valeur en Map<String,dynamic> et lit les clés 'timeline'
// et 'summary' séparément.
//
// Note : traceAction(reportKey: scenario) peuple automatiquement
// binding.reportData[scenario] avec la timeline sérialisée. Le driver
// n'a besoin que de la clé pour nommer les fichiers ; la valeur est une
// Map contenant les événements de trace.
//
// ⚠️ Device-bound : NE PAS exécuter sans device branché.
//    Vérification sans device : flutter analyze integration_test/ test_driver/
//
// Lancement :
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf/perf_scenarios_test.dart \
//     --dart-define-from-file=env.dev.json \
//     --profile \
//     -d <device-id>

// ignore_for_file: avoid_print

import 'package:dony/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'perf_harness.dart';

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────────────
  // A1 — cold_boot_to_home
  // Mesure le temps de rendu du premier home après le déverrouillage PIN.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A1 cold_boot_to_home', (tester) async {
    const scenario = 'cold_boot_to_home';
    await binding.traceAction(() async {
      await bootToHome(tester);
    }, reportKey: scenario);
    await dumpNetwork(scenario);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A2 — home_sheet_scroll
  // Fling répété sur le contenu scrollable du home (liste annonces / bottom
  // sheet principale).
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A2 home_sheet_scroll', (tester) async {
    const scenario = 'home_sheet_scroll';
    await bootToHome(tester);
    appRouter.go('/home');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.traceAction(() async {
      for (var i = 0; i < 5; i++) {
        // TODO(perf-run): confirm finder on device — utiliser find.byType(Scrollable).last
        // si le sheet scrollable n'est pas le premier Scrollable de l'arbre.
        await fling(
          tester,
          find.byType(Scrollable).last,
          const Offset(0, -400),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await fling(
          tester,
          find.byType(Scrollable).last,
          const Offset(0, 400),
        );
      }
    }, reportKey: scenario);
    await dumpNetwork(scenario);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A3 — home_map_interact
  // Glissement (pan) sur la carte Google Maps du home.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A3 home_map_interact', (tester) async {
    const scenario = 'home_map_interact';
    await bootToHome(tester);
    appRouter.go('/home');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.traceAction(() async {
      // TODO(perf-run): confirm finder on device — la carte peut être un
      // GoogleMap, MapWidget ou un GestureDetector wrappant la map.
      // On cherche le premier widget de type GestureDetector dans l'arbre
      // (la map est généralement le premier élément derrière la sheet).
      final mapCandidate = find.byType(GestureDetector).first;
      for (var i = 0; i < 3; i++) {
        await tester.fling(mapCandidate, const Offset(100, 0), 500);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.fling(mapCandidate, const Offset(-100, 0), 500);
        await tester.pump(const Duration(milliseconds: 300));
      }
    }, reportKey: scenario);
    await dumpNetwork(scenario);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A4 — chat_scroll
  // Scroll dans l'inbox Messages (liste de conversations).
  // Note : la route /conversations/:id requiert un ConversationModel en extra,
  // donc on scroll l'inbox (/messages) qui est accessible via la bottom nav.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A4 chat_scroll', (tester) async {
    const scenario = 'chat_scroll';
    await bootToHome(tester);
    appRouter.go('/messages');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.traceAction(() async {
      // TODO(perf-run): confirm finder on device — liste de conversations
      // (ListView) dans l'écran InboxScreen.
      final scrollable = find.byType(Scrollable).last;
      for (var i = 0; i < 5; i++) {
        await fling(tester, scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 200));
        await fling(tester, scrollable, const Offset(0, 300));
      }
    }, reportKey: scenario);
    await dumpNetwork(scenario);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A5 — announcements_list_scroll
  // Scroll dans la liste des annonces (onglet Activités → /announcements).
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A5 announcements_list_scroll', (tester) async {
    const scenario = 'announcements_list_scroll';
    await bootToHome(tester);
    appRouter.go('/announcements');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.traceAction(() async {
      // TODO(perf-run): confirm finder on device — liste dans MatchingManagementScreen.
      final scrollable = find.byType(Scrollable).last;
      for (var i = 0; i < 5; i++) {
        await fling(tester, scrollable, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 200));
        await fling(tester, scrollable, const Offset(0, 400));
      }
    }, reportKey: scenario);
    await dumpNetwork(scenario);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A6 — favoris_open_scroll
  // Ouverture de l'écran Favoris (hors shell, appRouter.go('/favoris'))
  // puis scroll de la liste.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A6 favoris_open_scroll', (tester) async {
    const scenario = 'favoris_open_scroll';
    await bootToHome(tester);
    await binding.traceAction(() async {
      appRouter.go('/favoris');
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // TODO(perf-run): confirm finder on device — FavoritesScreen contient
      // probablement un TabBarView avec des Scrollable dans chaque onglet.
      final scrollable = find.byType(Scrollable).last;
      for (var i = 0; i < 5; i++) {
        await fling(tester, scrollable, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 200));
        await fling(tester, scrollable, const Offset(0, 300));
      }
    }, reportKey: scenario);
    await dumpNetwork(scenario);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A7 — tab_switch_rapid
  // Tap rapide sur chaque onglet de la bottom nav ×10.
  // Tabs (index): 0=Rechercher, 1=Activités, 2=Suivi (orb), 3=Messages, 4=Moi.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A7 tab_switch_rapid', (tester) async {
    const scenario = 'tab_switch_rapid';
    await bootToHome(tester);
    appRouter.go('/home');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await binding.traceAction(() async {
      // Les onglets sont des DonyNavItem avec les labels 'Rechercher',
      // 'Activités', 'Messages', 'Moi'. L'orb Suivi (index 2) n'a pas de
      // label texte dans DonyNavItem, on le tappe via find.byType(Scrollable)
      // ou via appRouter.go('/tracking').
      // TODO(perf-run): confirm finder on device — les labels sont rendus
      // dans DonyNavItem ; si le finder par texte échoue, utiliser
      // find.byKey ou find.byWidgetPredicate.
      final tabLabels = ['Rechercher', 'Activités', 'Messages', 'Moi'];
      final tabRoutes = ['/home', '/announcements', '/messages', '/profile'];
      for (var round = 0; round < 10; round++) {
        final i = round % tabLabels.length;
        final labelFinder = find.text(tabLabels[i]);
        if (labelFinder.evaluate().isNotEmpty) {
          await tester.tap(labelFinder.first, warnIfMissed: false);
        } else {
          // Fallback : navigation GoRouter si le label n'est pas visible.
          // TODO(perf-run): confirm fallback needed on device.
          appRouter.go(tabRoutes[i]);
        }
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pumpAndSettle();
    }, reportKey: scenario);
    await dumpNetwork(scenario);
  });
}
