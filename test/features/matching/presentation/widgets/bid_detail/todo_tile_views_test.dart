// Mesures des tuiles « À traiter » : affichage une fois par colis, événement,
// tuile et statut, quel que soit le nombre de reconstructions ; ouverture
// d'un sheet de tuile.
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/mock_analytics_backend.dart';

TodoTileShown _shown({
  String event = 'evt',
  String tile = 'reschedule',
  String status = 'ACCEPTED',
  Map<String, Object> properties = const {
    'tile': 'reschedule',
    'status': 'ACCEPTED',
  },
}) => TodoTileShown(
  event,
  tile: tile,
  status: status,
  properties: () => properties,
);

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

  /// Image suivante : le corps appelle le journal pendant son `build`, donc
  /// pendant une image ; ici, hors image, on la demande.
  Future<void> frame(WidgetTester tester) async {
    tester.binding.scheduleFrame();
    await tester.pump();
  }

  /// Contexte monté sur lequel le journal s'appuie.
  Future<BuildContext> mount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox(key: Key('body')));
    return tester.element(find.byKey(const Key('body')));
  }

  testWidgets('émission après l\'image, une seule fois pour le même colis, '
      'événement, tuile et statut', (tester) async {
    final context = await mount(tester);
    final log = TodoTileViewLog();

    log.logAll(context, 'b1', [_shown()]);
    verifyNever(() => backend.capture(any(), any()));
    log.logAll(context, 'b1', [_shown()]);
    await frame(tester);
    log.logAll(context, 'b1', [_shown()]);
    await frame(tester);

    verify(
      () =>
          backend.capture('evt', {'tile': 'reschedule', 'status': 'ACCEPTED'}),
    ).called(1);
  });

  testWidgets('un autre statut, une autre tuile, un autre événement ou un '
      'autre colis réémettent', (tester) async {
    final context = await mount(tester);
    final log = TodoTileViewLog();

    log.logAll(context, 'b1', [
      _shown(),
      _shown(status: 'IN_TRANSIT', properties: const {'s': 2}),
      _shown(tile: 'recipient'),
      _shown(event: 'evt2'),
    ]);
    log.logAll(context, 'b2', [_shown()]);
    await frame(tester);

    verify(() => backend.capture('evt', any())).called(4);
    verify(() => backend.capture('evt2', any())).called(1);
  });

  testWidgets('propriétés construites seulement à l\'émission', (tester) async {
    final context = await mount(tester);
    final log = TodoTileViewLog();
    var built = 0;
    TodoTileShown counted() => TodoTileShown(
      'evt',
      tile: 'reschedule',
      status: 'ACCEPTED',
      properties: () {
        built++;
        return const {'tile': 'reschedule'};
      },
    );

    log.logAll(context, 'b1', [counted()]);
    expect(built, 0);
    await frame(tester);
    log.logAll(context, 'b1', [counted()]);
    await frame(tester);
    expect(built, 1);
  });

  testWidgets('contexte démonté avant l\'image : rien n\'est émis', (
    tester,
  ) async {
    final context = await mount(tester);
    final log = TodoTileViewLog();
    log.logAll(context, 'b1', [_shown()]);
    await tester.pumpWidget(const SizedBox());

    verifyNever(() => backend.capture(any(), any()));
  });

  testWidgets('sans service d\'analytics enregistré : rien ne casse', (
    tester,
  ) async {
    getIt.unregister<AnalyticsService>();
    final context = await mount(tester);
    final log = TodoTileViewLog();

    log.logAll(context, 'b1', [_shown()]);
    await frame(tester);
    expect(tester.takeException(), isNull);
  });

  test('logBidDetailTileOpened : tuile, rôle et source', () {
    logBidDetailTileOpened(
      tile: 'supplement',
      role: 'traveler',
      source: 'link',
    );

    verify(
      () => backend.capture(AnalyticsEvents.bidDetailTileOpened, {
        'tile': 'supplement',
        'role': 'traveler',
        'source': 'link',
      }),
    ).called(1);
  });

  test('logBidDetailTileOpened sans service d\'analytics : rien ne casse', () {
    getIt.unregister<AnalyticsService>();
    expect(
      () =>
          logBidDetailTileOpened(tile: 'colis', role: 'sender', source: 'tile'),
      returnsNormally,
    );
  });

  test('TodoSource : valeurs envoyées à PostHog', () {
    expect(TodoSource.values.map((s) => s.name), ['tile', 'link']);
  });
}
