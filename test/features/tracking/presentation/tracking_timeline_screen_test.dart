import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/presentation/widgets/route_map_components.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:dony/features/tracking/bloc/tracking_bloc.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/presentation/screens/tracking_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

const _emptyHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": []
}
''';

const _trackingHelpConfigJson = '''
{
  "schemaVersion": 1,
  "socialLinks": [],
  "tutorials": [
    {
      "id": "tracking_read",
      "title": "Lecture et suivi",
      "description": "Comprendre les étapes du transport de votre colis.",
      "youtubeVideoId": "dQw4w9WgXcQ",
      "order": 1,
      "active": true,
      "contexts": ["tracking"]
    }
  ]
}
''';

class _StaticHelpCenterSource implements HelpCenterConfigSource {
  const _StaticHelpCenterSource(this.json);

  final String json;

  @override
  String get activatedJson => json;

  @override
  Future<String?> fetchAndActivate() async => json;
}

class _MockTrackingBloc extends MockBloc<TrackingEvent, TrackingState>
    implements TrackingBloc {}

TrackingEventModel _event(String type) => TrackingEventModel(
  id: 'evt-$type',
  bidId: 'bid-1',
  eventType: type,
  scannedAt: DateTime(2026, 6, 20, 10),
  createdAt: DateTime(2026, 6, 20, 10),
);

Widget _wrap(
  TrackingBloc bloc, {
  String helpConfigJson = _emptyHelpConfigJson,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<TrackingBloc>.value(value: bloc),
            BlocProvider<HelpCenterBloc>(
              create: (_) => HelpCenterBloc(
                HelpCenterRepository(
                  _StaticHelpCenterSource(helpConfigJson),
                  fallbackJsonLoader: () async => _emptyHelpConfigJson,
                ),
                makeDisabledAnalytics(MockAnalyticsBackend()),
              )..add(const HelpCenterLoadRequested()),
            ),
          ],
          child: const TrackingTimelineScreen(
            bidId: 'bid-1',
            corridor: 'Paris → Dakar',
          ),
        ),
      ),
      GoRoute(
        path: '/profile/help/tutorial/:tutorialId',
        builder: (_, state) => Scaffold(
          body: Text('TutorialStub:${state.pathParameters['tutorialId']}'),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockTrackingBloc bloc;

  setUpAll(() {
    registerFallbackValue(TrackingEventsRequested('bid-1'));
  });

  setUp(() {
    bloc = _MockTrackingBloc();
  });

  testWidgets('affiche le chargement puis le résumé de statut du corridor', (
    tester,
  ) async {
    when(() => bloc.state).thenReturn(TrackingEventsLoading());
    await tester.pumpWidget(_wrap(bloc));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('affiche un message d\'erreur avec bouton réessayer', (
    tester,
  ) async {
    when(
      () => bloc.state,
    ).thenReturn(TrackingEventsError(const NetworkException('Erreur réseau')));
    await tester.pumpWidget(_wrap(bloc));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets(
    'affiche la carte tutoriel sous le résumé de statut et navigue au tap',
    (tester) async {
      when(
        () => bloc.state,
      ).thenReturn(TrackingEventsLoaded([_event('DEPART')]));
      await tester.pumpWidget(
        _wrap(bloc, helpConfigJson: _trackingHelpConfigJson),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final statusSummaryTop = tester.getTopLeft(find.byType(RouteMapCard)).dy;
      final cardTop = tester
          .getTopLeft(find.text('Besoin d\'aide ? Voir le tutoriel'))
          .dy;
      expect(cardTop, greaterThan(statusSummaryTop));

      await tester.tap(find.text('Besoin d\'aide ? Voir le tutoriel'));
      await tester.pumpAndSettle();

      expect(find.text('TutorialStub:tracking_read'), findsOneWidget);
    },
  );
}
