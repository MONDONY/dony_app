// Mesure d'affichage des tuiles « À traiter » : une fois par colis, tuile et
// statut, quel que soit le nombre de reconstructions.
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

void main() {
  late MockAnalyticsBackend backend;

  setUp(() async {
    backend = MockAnalyticsBackend();
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
    getIt.registerSingleton<AnalyticsService>(analytics);
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  const shown = TodoTileShown('evt', {
    'tile': 'reschedule',
    'status': 'ACCEPTED',
  }, status: 'ACCEPTED');

  test('une seule émission pour le même colis, tuile et statut', () {
    final log = TodoTileViewLog();

    log.logOnce(bidId: 'b1', tile: 'reschedule', shown: shown);
    log.logOnce(bidId: 'b1', tile: 'reschedule', shown: shown);

    verify(
      () =>
          backend.capture('evt', {'tile': 'reschedule', 'status': 'ACCEPTED'}),
    ).called(1);
  });

  test('un autre statut, une autre tuile ou un autre colis réémettent', () {
    final log = TodoTileViewLog();

    log.logOnce(bidId: 'b1', tile: 'reschedule', shown: shown);
    log.logOnce(
      bidId: 'b1',
      tile: 'reschedule',
      shown: const TodoTileShown('evt', {'s': 2}, status: 'IN_TRANSIT'),
    );
    log.logOnce(bidId: 'b1', tile: 'recipient', shown: shown);
    log.logOnce(bidId: 'b2', tile: 'reschedule', shown: shown);

    verify(() => backend.capture('evt', any())).called(4);
  });

  test('sans service d\'analytics enregistré : rien ne casse', () {
    getIt.unregister<AnalyticsService>();
    final log = TodoTileViewLog();

    expect(
      () => log.logOnce(bidId: 'b1', tile: 'reschedule', shown: shown),
      returnsNormally,
    );
  });
}
