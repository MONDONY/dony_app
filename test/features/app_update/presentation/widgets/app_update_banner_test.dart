import 'package:dony/core/design/widgets/dony_status_banner.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/app_update/bloc/app_update_banner_cubit.dart';
import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:dony/features/app_update/data/services/app_update_service.dart';
import 'package:dony/features/app_update/presentation/widgets/app_update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  var storeOpened = 0;
  setUp(() => storeOpened = 0);

  AppUpdateBannerCubit cubitFor({required int recommended}) =>
      AppUpdateBannerCubit(
        AppUpdateService(
          _FakeConfigSource(recommended),
          packageInfoLoader: () async => PackageInfo(
            appName: 'Yadony',
            packageName: 'com.yadony.yadony',
            version: '1.0.0',
            buildNumber: '40',
          ),
        ),
        _NoopAnalytics(),
        openStore: () async => storeOpened++,
      );

  Future<void> pump(
    WidgetTester tester,
    AppUpdateBannerCubit cubit, {
    Locale locale = const Locale('fr'),
    double width = 360,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        Scaffold(body: AppUpdateBanner(cubit: cubit)),
        locale: locale,
      ),
    );
    await cubit.check();
    await tester.pumpAndSettle();
  }

  testWidgets('reste invisible quand l\'app est à jour', (tester) async {
    final cubit = cubitFor(recommended: 0);
    addTearDown(cubit.close);

    await pump(tester, cubit);

    expect(find.text('Nouvelle version disponible'), findsNothing);
  });

  testWidgets('affiche titre, message et lien quand une version existe', (
    tester,
  ) async {
    final cubit = cubitFor(recommended: 50);
    addTearDown(cubit.close);

    await pump(tester, cubit);

    expect(find.text('Nouvelle version disponible'), findsOneWidget);
    expect(find.textContaining('Yadony'), findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le lien ouvre le store', (tester) async {
    final cubit = cubitFor(recommended: 50);
    addTearDown(cubit.close);
    await pump(tester, cubit);

    await tester.tap(find.text('Mettre à jour'));
    await tester.pump();

    expect(storeOpened, 1);
  });

  testWidgets('se ferme au clic sur la croix', (tester) async {
    final cubit = cubitFor(recommended: 50);
    addTearDown(cubit.close);
    await pump(tester, cubit);

    tester.widget<DonyStatusBanner>(find.byType(DonyStatusBanner)).onDismiss!();
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle version disponible'), findsNothing);
  });

  testWidgets('tient sur une ligne en anglais à 360 dp', (tester) async {
    enableEnglish();
    final cubit = cubitFor(recommended: 50);
    addTearDown(cubit.close);

    await pump(tester, cubit, locale: const Locale('en'));

    expect(find.text('New version available'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('n\'utilise jamais de tiret cadratin', (tester) async {
    final cubit = cubitFor(recommended: 50);
    addTearDown(cubit.close);
    await pump(tester, cubit);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');

    expect(texts.contains('—'), isFalse);
  });
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

final class _NoopAnalytics extends Fake implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object>? properties}) async {}
}
