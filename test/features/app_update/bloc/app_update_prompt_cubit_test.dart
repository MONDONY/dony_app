import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/app_update/bloc/app_update_prompt_cubit.dart';
import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:dony/features/app_update/data/services/app_update_service.dart';
import 'package:dony/features/app_update/data/services/app_update_snooze_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  final now = DateTime.utc(2026, 11, 9, 12);
  late _RecordingAnalytics analytics;
  late _MemoryStore store;
  var storeOpened = 0;

  setUp(() {
    analytics = _RecordingAnalytics();
    store = _MemoryStore();
    storeOpened = 0;
  });

  AppUpdatePromptCubit cubitFor({
    int recommended = 50,
    String installed = '40',
  }) => AppUpdatePromptCubit(
    AppUpdateService(
      _FakeConfigSource(recommended),
      packageInfoLoader: () async => PackageInfo(
        appName: 'Yadony',
        packageName: 'com.yadony.yadony',
        version: '1.0.0',
        buildNumber: installed,
      ),
    ),
    store,
    analytics,
    openStore: () async => storeOpened++,
    now: () => now,
  );

  Future<bool> shownAfterCheck({DateTime? snoozedAt}) async {
    store.value = snoozedAt;
    final cubit = cubitFor();
    addTearDown(cubit.close);
    await cubit.check();
    return cubit.state;
  }

  test('la durée de report est de 12 heures', () {
    expect(kAppUpdatePromptSnooze, const Duration(hours: 12));
  });

  test('démarre masqué', () {
    final cubit = cubitFor();
    addTearDown(cubit.close);
    expect(cubit.state, isFalse);
  });

  test('jamais reporté : s\'affiche et le mesure', () async {
    expect(await shownAfterCheck(), isTrue);
    expect(analytics.events, [AnalyticsEvents.appUpdateBannerShown]);
  });

  test('app à jour : rien', () async {
    final cubit = cubitFor(installed: '50');
    addTearDown(cubit.close);
    await cubit.check();
    expect(cubit.state, isFalse);
    expect(analytics.events, isEmpty);
  });

  test('reporté il y a moins de 12 h : masqué', () async {
    expect(
      await shownAfterCheck(
        snoozedAt: now.subtract(const Duration(hours: 11, minutes: 59)),
      ),
      isFalse,
    );
    expect(analytics.events, isEmpty);
  });

  test('reporté il y a 12 h pile : s\'affiche', () async {
    expect(
      await shownAfterCheck(snoozedAt: now.subtract(kAppUpdatePromptSnooze)),
      isTrue,
    );
  });

  test('reporté il y a plus de 12 h : s\'affiche', () async {
    expect(
      await shownAfterCheck(snoozedAt: now.subtract(const Duration(days: 3))),
      isTrue,
    );
  });

  test('horodatage dans le futur : traité comme jamais reporté', () async {
    expect(
      await shownAfterCheck(snoozedAt: now.add(const Duration(days: 30))),
      isTrue,
    );
  });

  test('horodatage illisible : traité comme jamais reporté', () async {
    final unreadable = PrefsAppUpdateSnoozeStore(
      prefs: () async => throw StateError('disque illisible'),
    );
    expect(await unreadable.lastSnoozedAt(), isNull);
    await expectLater(unreadable.snooze(now), completes);
  });

  test('une seule apparition par session', () async {
    final cubit = cubitFor();
    addTearDown(cubit.close);
    await cubit.check();
    expect(cubit.state, isTrue);
    await cubit.later();
    store.value = null;

    await cubit.check();

    expect(cubit.state, isFalse);
    expect(analytics.events, [
      AnalyticsEvents.appUpdateBannerShown,
      AnalyticsEvents.appUpdateBannerDismissed,
    ]);
  });

  test('later mémorise l\'horloge, masque et mesure', () async {
    final cubit = cubitFor();
    addTearDown(cubit.close);
    await cubit.check();
    analytics.events.clear();

    await cubit.later();

    expect(cubit.state, isFalse);
    expect(store.value, now);
    expect(analytics.events, [AnalyticsEvents.appUpdateBannerDismissed]);
  });

  test('update ouvre le store sans mémoriser de report', () async {
    final cubit = cubitFor();
    addTearDown(cubit.close);
    await cubit.check();
    analytics.events.clear();

    await cubit.update();

    expect(cubit.state, isFalse);
    expect(storeOpened, 1);
    expect(store.value, isNull);
    expect(analytics.events, [AnalyticsEvents.appUpdateBannerTapped]);
  });

  test('check après fermeture du cubit n\'émet rien', () async {
    final cubit = cubitFor();
    final check = cubit.check();
    await cubit.close();

    await expectLater(check, completes);
    expect(analytics.events, isEmpty);
  });
}

final class _MemoryStore implements AppUpdateSnoozeStore {
  DateTime? value;

  @override
  Future<DateTime?> lastSnoozedAt() async => value;

  @override
  Future<void> snooze(DateTime at) async => value = at;
}

final class _RecordingAnalytics extends Fake implements AnalyticsService {
  final events = <String>[];

  @override
  Future<void> logEvent(String name, {Map<String, Object>? properties}) async {
    events.add(name);
  }
}

final class _FakeConfigSource implements AppUpdateConfigSource {
  _FakeConfigSource(this.recommendedBuild);

  @override
  final int recommendedBuild;

  @override
  int get minSupportedBuild => 0;

  @override
  Future<void> fetchAndActivate() async {}
}
