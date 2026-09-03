import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_bloc.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_event.dart';
import 'package:dony/features/notifications/bloc/announcements_inbox_state.dart';
import 'package:dony/features/notifications/data/notification_model.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

NotificationModel _annonce({required String id, bool read = false}) =>
    NotificationModel(
      id: id,
      type: 'ADMIN_BROADCAST',
      category: 'annonce',
      title: 'Annonce $id',
      body: 'Corps.',
      data: const {},
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

  group('AnnouncementsInboxBloc', () {
    blocTest<AnnouncementsInboxBloc, AnnouncementsInboxState>(
      'charge les annonces et compte les non-lues depuis la liste',
      build: () {
        when(() => repository.getAnnouncements()).thenAnswer(
          (_) async => [_annonce(id: 'a'), _annonce(id: 'b', read: true)],
        );
        return AnnouncementsInboxBloc(repository, analytics);
      },
      act: (bloc) => bloc.add(const AnnouncementsInboxLoadRequested()),
      expect: () => [
        const AnnouncementsInboxLoading(),
        isA<AnnouncementsInboxLoaded>()
            .having((s) => s.announcements.length, 'count', 2)
            .having((s) => s.unreadCount, 'unread', 1),
      ],
      verify: (_) {
        verify(
          () => analytics.logEvent(
            AnalyticsEvents.announcementsInboxOpened,
            properties: {'count': 2, 'unread': 1},
          ),
        ).called(1);
      },
    );

    blocTest<AnnouncementsInboxBloc, AnnouncementsInboxState>(
      'passe en erreur si le serveur échoue',
      build: () {
        when(() => repository.getAnnouncements()).thenThrow(Exception('err'));
        return AnnouncementsInboxBloc(repository, analytics);
      },
      act: (bloc) => bloc.add(const AnnouncementsInboxLoadRequested()),
      expect: () => [
        const AnnouncementsInboxLoading(),
        isA<AnnouncementsInboxError>(),
      ],
    );

    blocTest<AnnouncementsInboxBloc, AnnouncementsInboxState>(
      'lire une annonce la marque lue et fait baisser le compteur',
      build: () {
        when(() => repository.markRead('a')).thenAnswer((_) async {});
        return AnnouncementsInboxBloc(repository, analytics);
      },
      seed: () =>
          AnnouncementsInboxLoaded([_annonce(id: 'a'), _annonce(id: 'b')]),
      act: (bloc) => bloc.add(const AnnouncementsInboxMarkReadRequested('a')),
      expect: () => [
        isA<AnnouncementsInboxLoaded>()
            .having((s) => s.announcements.first.read, 'a lue', true)
            .having((s) => s.unreadCount, 'unread', 1),
      ],
    );

    blocTest<AnnouncementsInboxBloc, AnnouncementsInboxState>(
      'lire une annonce déjà lue ne fait rien',
      build: () => AnnouncementsInboxBloc(repository, analytics),
      seed: () => AnnouncementsInboxLoaded([_annonce(id: 'a', read: true)]),
      act: (bloc) => bloc.add(const AnnouncementsInboxMarkReadRequested('a')),
      expect: () => <AnnouncementsInboxState>[],
      verify: (_) => verifyNever(() => repository.markRead(any())),
    );

    blocTest<AnnouncementsInboxBloc, AnnouncementsInboxState>(
      'restaure l\'état si la lecture échoue côté serveur',
      build: () {
        when(() => repository.markRead('a')).thenThrow(Exception('réseau'));
        return AnnouncementsInboxBloc(repository, analytics);
      },
      seed: () => AnnouncementsInboxLoaded([_annonce(id: 'a')]),
      act: (bloc) => bloc.add(const AnnouncementsInboxMarkReadRequested('a')),
      expect: () => [
        isA<AnnouncementsInboxLoaded>().having(
          (s) => s.unreadCount,
          'optimiste',
          0,
        ),
        isA<AnnouncementsInboxLoaded>().having(
          (s) => s.unreadCount,
          'restauré',
          1,
        ),
      ],
    );
  });
}
