import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/community_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../a11y/contrast_helpers.dart';
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
  AnalyticsService? analytics,
  TextScaler textScaler = TextScaler.noScaling,
  ThemeMode themeMode = ThemeMode.light,
}) {
  final effectiveAnalytics = analytics ?? makeEnabledAnalytics(backend);
  return BlocProvider(
    create: (_) => HelpCenterBloc(
      HelpCenterRepository(
        const _StaticHelpCenterSource(),
        fallbackJsonLoader: () async => _socialConfigJson,
        urlLauncher: launcher,
      ),
      effectiveAnalytics,
    )..add(const HelpCenterLoadRequested()),
    child: MaterialApp.router(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const CommunityScreen()),
        ],
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
      BlocProvider(
        create: (_) => HelpCenterBloc(
          HelpCenterRepository(
            const _StaticHelpCenterSource(),
            fallbackJsonLoader: () async => _socialConfigJson,
            urlLauncher: launcher,
          ),
          analytics,
        )..add(const HelpCenterLoadRequested()),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const CommunityScreen()),
            ],
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

  testWidgets('active Instagram par l’action sémantique une seule fois', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();

    await tester.pumpWidget(
      _wrap(backend: backend, launcher: launcher, analytics: analytics),
    );
    await tester.pumpAndSettle();

    final instagram = find.bySemanticsLabel('Suivre Instagram');
    await tester.ensureVisible(instagram);
    await tester.pumpAndSettle();
    final node = tester.getSemantics(instagram);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    _semanticsOwner(tester).performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(launcher.launchedUrls, ['https://community.example/instagram']);
    verify(
      () => backend.capture(AnalyticsEvents.helpSocialLinkOpened, {
        'network': 'instagram',
      }),
    ).called(1);
    semantics.dispose();
  });

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('garde le CTA Instagram contrasté en thème ${themeMode.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(backend: backend, launcher: launcher, themeMode: themeMode),
      );
      await tester.pumpAndSettle();

      const cardKey = Key('help-social-instagram');
      final action = find.descendant(
        of: find.byKey(cardKey),
        matching: find.text('Suivre'),
      );
      final actionText = tester.widget<Text>(action);
      final context = tester.element(find.byKey(cardKey));
      final theme = Theme.of(context);
      final expectedColor = themeMode == ThemeMode.light
          ? DonyColors.accent
          : DonyColors.terraDark500;

      expect(actionText.style?.color, expectedColor);
      expectContrast(
        actionText.style!.color!,
        theme.colorScheme.surface,
        Seuil.texte,
        'CTA Instagram sur la surface ${themeMode.name}',
      );
      expect(tester.takeException(), isNull);
    });
  }

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

SemanticsOwner _semanticsOwner(WidgetTester tester) =>
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!;
