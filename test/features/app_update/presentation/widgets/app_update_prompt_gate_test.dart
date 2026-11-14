import 'dart:async';

import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/app_update/bloc/app_update_prompt_cubit.dart';
import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:dony/features/app_update/data/services/app_update_service.dart';
import 'package:dony/features/app_update/data/services/app_update_snooze_store.dart';
import 'package:dony/features/app_update/presentation/widgets/app_update_prompt_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  final now = DateTime.utc(2026, 11, 9, 12);
  late _MemoryStore store;
  var storeOpened = 0;

  setUp(() {
    store = _MemoryStore();
    storeOpened = 0;
  });

  AppUpdatePromptCubit cubitFor({int recommended = 50}) => AppUpdatePromptCubit(
    AppUpdateService(
      _FakeConfigSource(recommended),
      packageInfoLoader: () async => PackageInfo(
        appName: 'Yadony',
        packageName: 'com.yadony.yadony',
        version: '1.0.0',
        buildNumber: '40',
      ),
    ),
    store,
    _NoopAnalytics(),
    openStore: () async => storeOpened++,
    now: () => now,
  );

  Future<AppUpdatePromptCubit> pump(
    WidgetTester tester, {
    Locale locale = const Locale('fr'),
    double width = 360,
    int recommended = 50,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = cubitFor(recommended: recommended);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      localizedApp(
        Scaffold(body: AppUpdatePromptGate(cubit: cubit)),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('rien quand l\'app est à jour', (tester) async {
    await pump(tester, recommended: 0);
    expect(find.text('Une mise à jour est disponible'), findsNothing);
  });

  testWidgets('rien quand reporté il y a moins de 12 h', (tester) async {
    store.value = now.subtract(const Duration(hours: 2));
    await pump(tester);
    expect(find.text('Une mise à jour est disponible'), findsNothing);
  });

  testWidgets('FR : titre, corps et deux boutons empilés sur une ligne', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Une mise à jour est disponible'), findsOneWidget);
    expect(find.textContaining('stabilité'), findsOneWidget);
    final update = find.byKey(const Key('app-update-prompt-update'));
    final later = find.byKey(const Key('app-update-prompt-later'));
    expect(
      find.descendant(of: update, matching: find.text('Mettre à jour')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: later, matching: find.text('Plus tard')),
      findsOneWidget,
    );
    // Empilés : le principal au-dessus, tous deux en pleine largeur.
    expect(tester.getTopLeft(update).dy, lessThan(tester.getTopLeft(later).dy));
    expect(tester.getSize(update).width, tester.getSize(later).width);
    expect(find.byType(DonyButton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('EN à 360 dp : libellés courts, pas d\'exception', (
    tester,
  ) async {
    await pump(tester, locale: const Locale('en'));

    expect(find.text('An update is available'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aucun tiret cadratin', (tester) async {
    await pump(tester);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');
    expect(texts.contains('—'), isFalse);
  });

  testWidgets('« Plus tard » mémorise l\'horodatage et ferme', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('app-update-prompt-later')));
    await tester.pumpAndSettle();

    expect(find.text('Une mise à jour est disponible'), findsNothing);
    expect(store.value, now);
    expect(storeOpened, 0);
  });

  testWidgets('tap à côté du modal vaut « Plus tard »', (tester) async {
    await pump(tester);

    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();

    expect(find.text('Une mise à jour est disponible'), findsNothing);
    expect(store.value, now);
    expect(storeOpened, 0);
  });

  testWidgets('« Mettre à jour » ouvre le store sans report', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('app-update-prompt-update')));
    await tester.pumpAndSettle();

    expect(find.text('Une mise à jour est disponible'), findsNothing);
    expect(storeOpened, 1);
    expect(store.value, isNull);
  });

  Future<void> background(WidgetTester tester) async {
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
  }

  Future<void> foreground(WidgetTester tester) async {
    for (final st in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('retour au premier plan : le modal réapparaît', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('app-update-prompt-update')));
    await tester.pumpAndSettle();
    expect(find.text('Une mise à jour est disponible'), findsNothing);

    await background(tester);
    await foreground(tester);

    expect(find.text('Une mise à jour est disponible'), findsOneWidget);
  });

  testWidgets('réouverture : le report de 12 h est respecté', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('app-update-prompt-later')));
    await tester.pumpAndSettle();

    await background(tester);
    await foreground(tester);

    expect(find.text('Une mise à jour est disponible'), findsNothing);
  });

  testWidgets('retour au premier plan : pas d\'empilement', (tester) async {
    await pump(tester);

    await background(tester);
    await foreground(tester);

    expect(find.text('Une mise à jour est disponible'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-update-prompt-later')));
    await tester.pumpAndSettle();
    expect(find.text('Une mise à jour est disponible'), findsNothing);
  });

  testWidgets('retour au premier plan : rien si l\'app est à jour', (
    tester,
  ) async {
    await pump(tester, recommended: 0);

    await background(tester);
    await foreground(tester);

    expect(find.text('Une mise à jour est disponible'), findsNothing);
  });

  testWidgets('autre écran plein par-dessus : rien, puis le modal au retour', (
    tester,
  ) async {
    store.value = now.subtract(const Duration(hours: 2));
    await pump(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Autre écran')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Le report expire pendant que le shell est recouvert.
    store.value = null;

    await background(tester);
    await foreground(tester);

    expect(find.text('Une mise à jour est disponible'), findsNothing);
    expect(store.value, isNull);

    navigator.pop();
    await tester.pumpAndSettle();
    await background(tester);
    await foreground(tester);

    expect(find.text('Une mise à jour est disponible'), findsOneWidget);
  });
}

final class _MemoryStore implements AppUpdateSnoozeStore {
  DateTime? value;

  @override
  Future<DateTime?> lastSnoozedAt() async => value;

  @override
  Future<void> snooze(DateTime at) async => value = at;
}

final class _FakeConfigSource implements AppUpdateConfigSource {
  _FakeConfigSource(this.recommendedBuild);

  @override
  final int recommendedBuild;

  @override
  int get minSupportedBuild => 0;

  @override
  Future<void> fetchAndActivate() async {}

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  void startRealtimeUpdates() {}

  @override
  Future<void> stopRealtimeUpdates() async {}
}

final class _NoopAnalytics extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object>? properties}) async {}
}
