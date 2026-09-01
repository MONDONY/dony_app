import 'package:dony/core/di/injection.dart';
import 'package:dony/features/subscriptions/data/subscription_badge_consumer.dart';
import 'package:dony/features/subscriptions/data/subscriptions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements SubscriptionsRepository {}

void main() {
  late MockRepo repo;

  setUp(() {
    repo = MockRepo();
    when(() => repo.markSeen(any())).thenAnswer((_) async {});
    if (getIt.isRegistered<SubscriptionsRepository>()) {
      getIt.unregister<SubscriptionsRepository>();
    }
    getIt.registerSingleton<SubscriptionsRepository>(repo);
  });

  tearDown(() => getIt.unregister<SubscriptionsRepository>());

  test('ouvrir la notification d\'un voyageur suivi consomme sa pastille', () async {
    await consumeSubscriptionBadge('TRAVELER_NEW_ANNOUNCEMENT', {
      'travelerId': 't-1',
      'announcementId': 'a-1',
    });

    verify(() => repo.markSeen('t-1')).called(1);
  });

  test('un autre type de notification ne touche à rien', () async {
    await consumeSubscriptionBadge('CORRIDOR_ALERT', {'travelerId': 't-1'});
    verifyNever(() => repo.markSeen(any()));
  });

  test('travelerId absent ou mal typé → aucun appel', () async {
    await consumeSubscriptionBadge('TRAVELER_NEW_ANNOUNCEMENT', const {});
    await consumeSubscriptionBadge('TRAVELER_NEW_ANNOUNCEMENT', {
      'travelerId': 42,
    });
    await consumeSubscriptionBadge('TRAVELER_NEW_ANNOUNCEMENT', {
      'travelerId': '',
    });
    verifyNever(() => repo.markSeen(any()));
  });

  test('un échec réseau reste silencieux', () async {
    when(() => repo.markSeen(any())).thenThrow(Exception('hors ligne'));

    // Ne doit pas relancer : la navigation ne doit jamais dépendre de cet
    // effet de bord d'affichage.
    await expectLater(
      consumeSubscriptionBadge('TRAVELER_NEW_ANNOUNCEMENT', {
        'travelerId': 't-1',
      }),
      completes,
    );
  });
}
