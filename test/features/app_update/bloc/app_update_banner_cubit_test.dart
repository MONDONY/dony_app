import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/app_update/bloc/app_update_banner_cubit.dart';
import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:dony/features/app_update/data/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  late _RecordingAnalytics analytics;
  var storeOpened = 0;

  setUp(() {
    analytics = _RecordingAnalytics();
    storeOpened = 0;
  });

  AppUpdateBannerCubit cubitFor({
    required int recommended,
    required String installed,
  }) => AppUpdateBannerCubit(
    AppUpdateService(
      _FakeConfigSource(recommended),
      packageInfoLoader: () async => PackageInfo(
        appName: 'Yadony',
        packageName: 'com.yadony.yadony',
        version: '1.0.0',
        buildNumber: installed,
      ),
    ),
    analytics,
    openStore: () async => storeOpened++,
  );

  test('démarre masqué', () {
    final cubit = cubitFor(recommended: 50, installed: '40');
    addTearDown(cubit.close);

    expect(cubit.state, isFalse);
  });

  test('check affiche le bandeau et le mesure', () async {
    final cubit = cubitFor(recommended: 50, installed: '40');
    addTearDown(cubit.close);

    await cubit.check();

    expect(cubit.state, isTrue);
    expect(analytics.events, [AnalyticsEvents.appUpdateBannerShown]);
  });

  test('check laisse le bandeau masqué quand l\'app est à jour', () async {
    final cubit = cubitFor(recommended: 50, installed: '50');
    addTearDown(cubit.close);

    await cubit.check();

    expect(cubit.state, isFalse);
    expect(analytics.events, isEmpty);
  });

  test('dismiss masque le bandeau et le mesure', () async {
    final cubit = cubitFor(recommended: 50, installed: '40');
    addTearDown(cubit.close);
    await cubit.check();
    analytics.events.clear();

    cubit.dismiss();

    expect(cubit.state, isFalse);
    expect(analytics.events, [AnalyticsEvents.appUpdateBannerDismissed]);
  });

  test('dismiss sur un bandeau déjà masqué ne mesure rien', () {
    final cubit = cubitFor(recommended: 50, installed: '40');
    addTearDown(cubit.close);

    cubit.dismiss();

    expect(analytics.events, isEmpty);
  });

  test('openStore mesure le toucher puis ouvre le store', () async {
    final cubit = cubitFor(recommended: 50, installed: '40');
    addTearDown(cubit.close);

    await cubit.openStore();

    expect(analytics.events, [AnalyticsEvents.appUpdateBannerTapped]);
    expect(storeOpened, 1);
  });

  test('check après fermeture du cubit n\'émet rien', () async {
    final cubit = cubitFor(recommended: 50, installed: '40');
    final check = cubit.check();
    await cubit.close();

    await expectLater(check, completes);
    expect(analytics.events, isEmpty);
  });
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
