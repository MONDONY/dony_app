// integration_test/perf/stress_scenarios_test.dart
//
// Scénarios stress montée en charge UI — A8, A9, A10.
//
// Ces scénarios sont DEVICE-BOUND — ne pas exécuter sans device branché.
// Vérification sans device : flutter analyze integration_test/
//
// Lancement :
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf/stress_scenarios_test.dart \
//     --dart-define-from-file=env.dev.json \
//     --profile \
//     -d <device-id>

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dony/app/router.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'perf_harness.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a minimal but valid [AnnouncementModel] suitable for use as feed-card
/// test data. All required fields are filled with realistic-looking values;
/// optional fields are left null/empty so the card renders the lightweight path.
///
/// Seed mechanism: A8 uses the real [TripCard] widget driven by these fake-but-
/// valid [AnnouncementModel] instances. No app boot, no DI, no network — the card
/// renders in a standalone MaterialApp. [FavoriteIdsCubit] is absent from the
/// tree; TripCard.showFavorite defaults to false so no cubit is needed.
AnnouncementModel _fakeAnnouncement(int index) {
  final now = DateTime.now();
  return AnnouncementModel(
    id: 'stress-$index',
    travelerId: 'traveler-$index',
    departureCity: 'Paris',
    arrivalCity: 'Dakar',
    departureFlag: '🇫🇷',
    arrivalFlag: '🇸🇳',
    departureCountryCode: 'FR',
    arrivalCountryCode: 'SN',
    departureDate: now.add(Duration(days: index % 30)),
    availableKg: (20 - index % 15).toDouble(),
    totalKg: 20,
    pricePerKg: 10 + (index % 5).toDouble(),
    status: 'ACTIVE',
    createdAt: now,
    updatedAt: now,
    transportMode: TransportMode.plane,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// A8 — stress_long_list
//
// Stress test: 500 TripCard widgets in a ListView.builder, no app boot.
// Measures list-render + sustained fling throughput to surface per-card
// build cost under volume.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('A8 stress_long_list', (tester) async {
    const scenario = 'stress_long_list';
    const itemCount = 500;

    // Pump a test-only widget — no app boot, no DI, no Firebase.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) => TripCard(
              announcement: _fakeAnnouncement(index),
              onTap: () {},
              index: index,
              // showFavorite defaults to false — no FavoriteIdsCubit needed.
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await binding.traceAction(
      () async {
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 8; i++) {
          await tester.fling(scrollable, const Offset(0, -600), 3000);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.fling(scrollable, const Offset(0, 600), 3000);
          await tester.pump(const Duration(milliseconds: 300));
        }
      },
      reportKey: scenario,
    );
    await dumpNetwork(scenario);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A9 — stress_many_markers
  //
  // Stress test: 300 small positioned marker widgets in a Stack over a
  // colored box, driven by a ValueNotifier-triggered rebuild. No app boot.
  //
  // NOTE: real GoogleMap markers are measured on-device via A3; this isolates
  // marker widget count cost independently of the platform map view.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A9 stress_many_markers', (tester) async {
    const scenario = 'stress_many_markers';
    const markerCount = 300; // N × 100 = 3 × 100

    final positionNotifier = ValueNotifier<double>(0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<double>(
            valueListenable: positionNotifier,
            builder: (context, offset, _) {
              return SizedBox.expand(
                child: Stack(
                  children: [
                    // Simulated map background.
                    Container(color: const Color(0xFFCDE6F0)),
                    // 300 marker widgets spread across the surface.
                    for (var i = 0; i < markerCount; i++)
                      Positioned(
                        left: (i % 20) * 18.0 + offset,
                        top: (i ~/ 20) * 22.0 + offset * 0.5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B5FFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await binding.traceAction(
      () async {
        // Trigger 30 setState-equivalent repositions via ValueNotifier.
        for (var step = 0; step < 30; step++) {
          positionNotifier.value = (step % 5) * 10.0;
          await tester.pump(const Duration(milliseconds: 16));
        }
        positionNotifier.value = 0;
        await tester.pump();
      },
      reportKey: scenario,
    );
    await dumpNetwork(scenario);

    positionNotifier.dispose();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // A10 — stress_nav_loop
  //
  // Stress test: 50 push/pop navigation cycles between /favoris and /home
  // via appRouter, using the real app. Captures RSS memory delta so a growing
  // heap (potential navigator leak) is visible in the perf report.
  // ─────────────────────────────────────────────────────────────────────────
  testWidgets('A10 stress_nav_loop', (tester) async {
    const scenario = 'stress_nav_loop';
    await bootToHome(tester);

    // Capture RSS before the navigation loop.
    final rssBefore = ProcessInfo.currentRss;

    await binding.traceAction(
      () async {
        for (var i = 0; i < 50; i++) {
          appRouter.go('/favoris');
          await tester.pumpAndSettle(const Duration(milliseconds: 300));
          appRouter.go('/home');
          await tester.pumpAndSettle(const Duration(milliseconds: 300));
        }
      },
      reportKey: scenario,
    );

    // Capture RSS after the loop and store delta in reportData.
    final rssAfter = ProcessInfo.currentRss;
    (binding.reportData ??= {})['${scenario}_rss'] = {
      'rssBeforeBytes': rssBefore,
      'rssAfterBytes': rssAfter,
      'deltaBytes': rssAfter - rssBefore,
    };
    print(
      '[perf] $scenario RSS delta: ${rssAfter - rssBefore} bytes '
      '(before=$rssBefore, after=$rssAfter)',
    );

    await dumpNetwork(scenario);
  });
}
