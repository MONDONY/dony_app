import 'dart:io';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/presentation/screens/offline_scan_queue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

late Directory _tempDir;
late HiveService _hiveService;

Future<void> _setUpHive() async {
  _tempDir = await Directory.systemTemp.createTemp('offline_queue_test_');
  Hive.init(_tempDir.path);
  await Hive.openBox<Map>(HiveService.offlineQueueBox);
  _hiveService = HiveService();

  if (getIt.isRegistered<HiveService>()) {
    getIt.unregister<HiveService>();
  }
  getIt.registerSingleton<HiveService>(_hiveService);
}

Future<void> _tearDownHive() async {
  await Hive.close();
  await _tempDir.delete(recursive: true);
  if (getIt.isRegistered<HiveService>()) {
    getIt.unregister<HiveService>();
  }
}

Widget _buildApp() => MaterialApp.router(
  theme: AppTheme.light(),
  routerConfig: GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const OfflineScanQueueScreen()),
    ],
  ),
);

void main() {
  setUpAll(() async => _setUpHive());
  tearDownAll(() async => _tearDownHive());

  setUp(() async {
    // Clear queue between tests
    await Hive.box<Map>(HiveService.offlineQueueBox).clear();
  });

  group('OfflineScanQueueScreen — empty queue', () {
    testWidgets('shows Vos scans sont en sécurité alert', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text('Vos lectures sont en sécurité'), findsOneWidget);
    });

    testWidgets('shows FILE D\'ATTENTE — 0 when empty', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text("FILE D'ATTENTE (0)"), findsOneWidget);
    });

    testWidgets('shows empty state message when queue is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text('Aucune lecture en attente.'), findsOneWidget);
    });
  });

  group('OfflineScanQueueScreen — with queue items', () {
    setUp(() async {
      final now = DateTime.now().toUtc();
      await Hive.box<Map>(HiveService.offlineQueueBox).addAll([
        {
          'bidId': 'A47C000000',
          'eventType': 'PICKUP',
          'offlineTimestamp': now
              .subtract(const Duration(minutes: 2))
              .toIso8601String(),
        },
        {
          'bidId': 'B891X00000',
          'eventType': 'IN_TRANSIT',
          'offlineTimestamp': now
              .subtract(const Duration(minutes: 4))
              .toIso8601String(),
        },
      ]);
    });

    testWidgets('shows correct count in section header', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text("FILE D'ATTENTE (2)"), findsOneWidget);
    });

    testWidgets('shows short bid codes for each item', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.textContaining('colis #A47C'), findsOneWidget);
      expect(find.textContaining('colis #B891'), findsOneWidget);
    });

    testWidgets('shows correct count in alert banner subtitle', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.textContaining('2 lectures en attente'), findsOneWidget);
    });

    testWidgets('shows Hors-ligne chip in appbar', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(find.text('Hors-ligne'), findsOneWidget);
    });

    testWidgets('shows footer message', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      expect(
        find.text('Continuez les lectures même sans réseau.'),
        findsOneWidget,
      );
    });
  });
}
