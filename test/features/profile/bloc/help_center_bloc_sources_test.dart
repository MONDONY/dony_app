import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/data/repositories/help_center_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

final class _EmptySource implements HelpCenterConfigSource {
  @override
  String get activatedJson => '';

  @override
  Future<String?> fetchAndActivate() async => null;
}

void main() {
  // Chaque contexte d'entrée d'un tutoriel a son nom stable côté PostHog :
  // un renommage casserait les tableaux de bord de l'entonnoir d'aide.
  const expected = {
    TutorialContext.corridorAlerts: 'corridor_alerts',
    TutorialContext.tripTemplates: 'trip_templates',
    TutorialContext.recipients: 'recipients',
    TutorialContext.receivedRequests: 'received_requests',
    TutorialContext.walletTopup: 'wallet_topup',
  };

  for (final entry in expected.entries) {
    test('help_tutorial_opened depuis ${entry.key.name} → source '
        '« ${entry.value} »', () async {
      final backend = MockAnalyticsBackend();
      final analytics = makeEnabledAnalytics(backend);
      await analytics.onConfigured();
      final bloc = HelpCenterBloc(
        HelpCenterRepository(
          _EmptySource(),
          fallbackJsonLoader: () async => '{}',
        ),
        analytics,
      );

      bloc.add(
        HelpTutorialOpenRequested(tutorialId: 'tuto-1', source: entry.key),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => backend.capture(AnalyticsEvents.helpTutorialOpened, {
          'tutorial_id': 'tuto-1',
          'source': entry.value,
        }),
      ).called(1);
      await bloc.close();
    });
  }
}
