import 'dart:async';

import 'package:dony/app/router.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/profile/presentation/screens/help_tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_analytics_backend.dart';

const _configJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "search_intro",
      "title": "Découvrir Yadony",
      "description": "Comprendre la recherche en quelques minutes.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["search"]
    }
  ]
}
''';

void main() {
  testWidgets(
    'la route de production transmet tutorialId sans dépendre de extra',
    (tester) async {
      const source = _StaticHelpCenterSource(_configJson);
      final analytics = makeDisabledAnalytics(MockAnalyticsBackend());
      final configurations = <HelpTutorialPlayerConfiguration>[];
      final sessions = <_RoutePlayerSession>[];
      final bloc = HelpCenterBloc(
        HelpCenterRepository(
          source,
          fallbackJsonLoader: () async => _configJson,
        ),
        analytics,
      )..add(const HelpCenterLoadRequested());
      final router = GoRouter(
        initialLocation: '/profile/help/tutorial/search_intro',
        routes: [
          buildHelpTutorialRoute(
            playerSessionFactory: (configuration) {
              configurations.add(configuration);
              final session = _RoutePlayerSession();
              sessions.add(session);
              return session;
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Découvrir Yadony'), findsOneWidget);
      expect(find.byKey(const Key('route-player')), findsOneWidget);
      expect(configurations.single.videoId, 'dQw4w9WgXcQ');
      expect(
        router.routeInformationProvider.value.uri.path,
        '/profile/help/tutorial/search_intro',
      );
    },
  );
}

final class _RoutePlayerSession implements HelpTutorialPlayerSession {
  final _events = StreamController<HelpTutorialPlayerEvent>.broadcast();

  @override
  Stream<HelpTutorialPlayerEvent> get events => _events.stream;

  @override
  Widget buildInline({required Widget Function(Widget player) frameBuilder}) {
    return frameBuilder(
      const ColoredBox(key: Key('route-player'), color: Colors.black),
    );
  }

  @override
  Future<void> close() => _events.close();
}

final class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}
