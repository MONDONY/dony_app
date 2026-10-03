import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/calls/bloc/call_lock_screen_cubit.dart';
import 'package:dony/features/calls/data/call_lock_screen_service.dart';
import 'package:dony/features/calls/presentation/widgets/call_lock_screen_prompt.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mock_analytics_backend.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

/// FLUTTER-92 : appel Yadony entrant invisible sur un Android verrouillé.
void main() {
  late _MockAnalytics analytics;
  late MockHiveService hive;
  late MockBox box;
  final opened = <LockScreenCallBlocker>[];

  CallLockScreenService service({
    bool android = true,
    bool fullScreen = true,
    String brand = 'Google',
    bool throws = false,
  }) => CallLockScreenService(
    isAndroid: () => android,
    canUseFullScreenIntent: () async {
      if (throws) throw StateError('no plugin');
      return fullScreen;
    },
    manufacturer: () async => brand,
    openFullScreenIntentSettings: () async =>
        opened.add(LockScreenCallBlocker.fullScreenIntent),
    openAppSettings: () async => opened.add(LockScreenCallBlocker.manufacturer),
  );

  setUp(() {
    opened.clear();
    analytics = _MockAnalytics();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    hive = MockHiveService();
    box = MockBox();
    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => box.get(
        HiveService.kCallLockScreenPromptShown,
        defaultValue: any(named: 'defaultValue'),
      ),
    ).thenReturn(false);
    when(() => box.put(any(), any())).thenAnswer((_) async {});
  });

  group('CallLockScreenService.blocker', () {
    test('plein écran refusé (Android 14+) → fullScreenIntent', () async {
      expect(
        await service(fullScreen: false).blocker(),
        LockScreenCallBlocker.fullScreenIntent,
      );
    });

    test('Xiaomi / Redmi / POCO → manufacturer', () async {
      for (final brand in ['Xiaomi', 'redmi', ' POCO ']) {
        expect(
          await service(brand: brand).blocker(),
          LockScreenCallBlocker.manufacturer,
        );
      }
    });

    test('autre Android autorisé, iOS ou plugin absent → none', () async {
      expect(await service().blocker(), LockScreenCallBlocker.none);
      expect(
        await service(android: false, fullScreen: false).blocker(),
        LockScreenCallBlocker.none,
      );
      expect(await service(throws: true).blocker(), LockScreenCallBlocker.none);
    });

    test('ouvre le réglage correspondant', () async {
      final s = service();
      await s.openSettings(LockScreenCallBlocker.fullScreenIntent);
      await s.openSettings(LockScreenCallBlocker.manufacturer);
      await s.openSettings(LockScreenCallBlocker.none);
      expect(opened, [
        LockScreenCallBlocker.fullScreenIntent,
        LockScreenCallBlocker.manufacturer,
      ]);
    });
  });

  group('CallLockScreenCubit', () {
    test(
      'ne propose la feuille qu\'une fois, et seulement si bloqué',
      () async {
        final blocked = CallLockScreenCubit(
          service(fullScreen: false),
          hive,
          analytics,
        );
        expect(await blocked.shouldPrompt(), isTrue);

        when(
          () => box.get(
            HiveService.kCallLockScreenPromptShown,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn(true);
        expect(await blocked.shouldPrompt(), isFalse);

        final fine = CallLockScreenCubit(service(), hive, analytics);
        expect(await fine.shouldPrompt(), isFalse);
      },
    );

    test('markPromptShown mémorise et trace le type de blocage', () async {
      final cubit = CallLockScreenCubit(
        service(fullScreen: false),
        hive,
        analytics,
      );
      await cubit.load();
      cubit.markPromptShown();

      verify(
        () => box.put(HiveService.kCallLockScreenPromptShown, true),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.callLockScreenPromptShown,
          properties: {'kind': 'full_screen_intent'},
        ),
      ).called(1);
    });

    test('openSettings trace la source et ouvre le réglage', () async {
      final cubit = CallLockScreenCubit(
        service(brand: 'Xiaomi'),
        hive,
        analytics,
      );
      await cubit.load();
      await cubit.openSettings(source: 'settings');

      expect(opened, [LockScreenCallBlocker.manufacturer]);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.callLockScreenSettingsOpened,
          properties: {'kind': 'manufacturer', 'source': 'settings'},
        ),
      ).called(1);
    });

    test('rien à ouvrir quand rien ne bloque', () async {
      final cubit = CallLockScreenCubit(service(), hive, analytics);
      await cubit.load();
      await cubit.openSettings(source: 'settings');
      expect(opened, isEmpty);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.callLockScreenSettingsOpened,
          properties: any(named: 'properties'),
        ),
      );
    });
  });

  group('interface', () {
    Widget app(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

    testWidgets('la feuille s\'affiche et ouvre les réglages', (tester) async {
      final cubit = CallLockScreenCubit(
        service(fullScreen: false),
        hive,
        analytics,
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  CallLockScreenPrompt.maybeShow(context, cubit: cubit),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Ne manquez aucun appel'), findsOneWidget);
      await tester.tap(find.byKey(const Key('call-lock-screen-open-settings')));
      await tester.pumpAndSettle();

      expect(find.text('Ne manquez aucun appel'), findsNothing);
      expect(opened, [LockScreenCallBlocker.fullScreenIntent]);
    });

    testWidgets('pas de feuille quand rien ne bloque', (tester) async {
      final cubit = CallLockScreenCubit(service(), hive, analytics);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  CallLockScreenPrompt.maybeShow(context, cubit: cubit),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Ne manquez aucun appel'), findsNothing);
    });

    testWidgets('la ligne des réglages montre l\'état et ouvre le réglage', (
      tester,
    ) async {
      final cubit = CallLockScreenCubit(
        service(fullScreen: false),
        hive,
        analytics,
      );
      await tester.pumpWidget(app(CallLockScreenTile(cubit: cubit)));
      await tester.pumpAndSettle();

      expect(find.text("Appels sur l'écran verrouillé"), findsOneWidget);
      await tester.tap(find.text("Appels sur l'écran verrouillé"));
      await tester.pumpAndSettle();
      expect(opened, [LockScreenCallBlocker.fullScreenIntent]);
    });

    testWidgets('la ligne indique quand tout est autorisé', (tester) async {
      final cubit = CallLockScreenCubit(service(), hive, analytics);
      await tester.pumpWidget(app(CallLockScreenTile(cubit: cubit)));
      await tester.pumpAndSettle();
      expect(
        find.text('Les appels Yadony s’affichent même téléphone verrouillé.'),
        findsOneWidget,
      );
    });
  });
}
