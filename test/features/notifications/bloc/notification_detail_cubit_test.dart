import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/notifications/bloc/notification_detail_cubit.dart';
import 'package:dony/features/notifications/data/notification_detail.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

NotificationDetail _detail({bool read = false}) => NotificationDetail(
  id: 'a1',
  type: 'ADMIN_BROADCAST',
  category: 'annonce',
  title: 'Maintenance',
  body: 'Court.',
  fullBody: 'Complet.',
  read: read,
  createdAt: DateTime(2026, 9, 3, 10),
);

void main() {
  late MockNotificationRepository repository;
  late MockAnalyticsService analytics;

  setUp(() {
    repository = MockNotificationRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
  });

  blocTest<NotificationDetailCubit, NotificationDetailState>(
    'charge le détail, trace l\'ouverture et marque lue une non-lue',
    build: () {
      when(() => repository.getDetail('a1')).thenAnswer((_) async => _detail());
      when(() => repository.markRead('a1')).thenAnswer((_) async {});
      return NotificationDetailCubit(repository, analytics);
    },
    act: (cubit) => cubit.load('a1'),
    expect: () => [
      const NotificationDetailLoading(),
      isA<NotificationDetailLoaded>().having(
        (s) => s.detail.text,
        'texte',
        'Complet.',
      ),
    ],
    verify: (_) {
      verify(() => repository.markRead('a1')).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.notificationDetailOpened,
          properties: {'type': 'ADMIN_BROADCAST', 'category': 'annonce'},
        ),
      ).called(1);
    },
  );

  blocTest<NotificationDetailCubit, NotificationDetailState>(
    'une notification déjà lue n\'est pas remarquée lue',
    build: () {
      when(
        () => repository.getDetail('a1'),
      ).thenAnswer((_) async => _detail(read: true));
      return NotificationDetailCubit(repository, analytics);
    },
    act: (cubit) => cubit.load('a1'),
    expect: () => [
      const NotificationDetailLoading(),
      isA<NotificationDetailLoaded>(),
    ],
    verify: (_) => verifyNever(() => repository.markRead(any())),
  );

  blocTest<NotificationDetailCubit, NotificationDetailState>(
    'introuvable ou hors ligne : état d\'erreur explicite',
    build: () {
      when(() => repository.getDetail('a1')).thenThrow(Exception('404'));
      return NotificationDetailCubit(repository, analytics);
    },
    act: (cubit) => cubit.load('a1'),
    expect: () => [
      const NotificationDetailLoading(),
      isA<NotificationDetailError>(),
    ],
  );
}
