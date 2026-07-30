import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/profile/bloc/faq_bloc.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/faq_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/mock_analytics_backend.dart';

const _socialConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [
    {
      "network": "whatsapp",
      "url": "https://community.example/whatsapp",
      "active": true
    },
    {
      "network": "facebook",
      "url": "https://community.example/facebook",
      "active": false
    },
    {
      "network": "instagram",
      "url": "https://community.example/instagram",
      "active": true
    },
    {
      "network": "tiktok",
      "url": "https://community.example/tiktok",
      "active": true
    },
    {
      "network": "youtube",
      "url": "https://community.example/youtube",
      "active": true
    }
  ],
  "tutorials": []
}
''';

Widget _wrap({
  required MockAnalyticsBackend backend,
  required _RecordingLauncher launcher,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final analytics = makeEnabledAnalytics(backend);
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => FaqBloc(analytics)),
      BlocProvider(
        create: (_) => HelpCenterBloc(
          HelpCenterRepository(
            const _StaticHelpCenterSource(),
            fallbackJsonLoader: () async => _socialConfigJson,
            urlLauncher: launcher,
          ),
          analytics,
        )..add(const HelpCenterLoadRequested()),
      ),
    ],
    child: MaterialApp.router(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const FaqScreen())],
      ),
    ),
  );
}

void main() {
  late MockAnalyticsBackend backend;
  late _RecordingLauncher launcher;

  setUp(() {
    backend = MockAnalyticsBackend();
    launcher = _RecordingLauncher();
  });

  testWidgets('masque un réseau inactif et adapte les libellés d’action', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(backend: backend, launcher: launcher));
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Facebook'), findsNothing);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
    expect(find.text('Suivre'), findsNWidgets(2));
    expect(find.text('S’abonner'), findsOneWidget);
  });

  testWidgets('ouvre le bon lien social et trace le réseau sans PII', (
    tester,
  ) async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => FaqBloc(analytics)),
          BlocProvider(
            create: (_) => HelpCenterBloc(
              HelpCenterRepository(
                const _StaticHelpCenterSource(),
                fallbackJsonLoader: () async => _socialConfigJson,
                urlLauncher: launcher,
              ),
              analytics,
            )..add(const HelpCenterLoadRequested()),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => const FaqScreen())],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final instagram = find.byKey(const Key('help-social-instagram'));
    await tester.ensureVisible(instagram);
    await tester.tap(instagram);
    await tester.pumpAndSettle();

    expect(launcher.launchedUrls, ['https://community.example/instagram']);
    verify(
      () => backend.capture(AnalyticsEvents.helpSocialLinkOpened, {
        'network': 'instagram',
      }),
    ).called(1);
  });

  testWidgets('reste lisible avec un facteur de texte 2.0', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        backend: backend,
        launcher: launcher,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

final class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource();

  @override
  String get activatedJson => _socialConfigJson;

  @override
  Future<String?> fetchAndActivate() async => _socialConfigJson;
}

final class _RecordingLauncher extends UrlLauncherPlatform {
  final launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}
