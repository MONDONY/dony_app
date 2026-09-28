import 'package:dony/core/di/injection.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_live_events.dart';
import 'package:dony/features/support/data/support_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockDeviceIdService extends Mock implements DeviceIdService {}

class MockSupportRepository extends Mock implements SupportRepository {}

const _ticketId = '123e4567-e89b-12d3-a456-426614174000';
const _supportData = {'type': 'SUPPORT_MESSAGE', 'ticketId': _ticketId};

void main() {
  late NotificationService service;

  setUp(() {
    service = NotificationService(
      MockApiClient(),
      MockNotificationRepository(),
      MockDeviceIdService(),
    );
  });

  group(
    'SUPPORT_MESSAGE : tap sur la push (app fermée ou en arrière-plan)',
    () {
      test('ouvre directement la conversation', () {
        expect(
          service.testRouteForMessage(_supportData),
          '/support/tickets/$_ticketId',
        );
      });

      test('sans ticketId, ouvre la liste du support', () {
        expect(
          service.testRouteForMessage({'type': 'SUPPORT_MESSAGE'}),
          '/support',
        );
      });
    },
  );

  group('isViewingSupportTicket', () {
    test('vrai seulement sur l écran de cette conversation', () {
      expect(
        NotificationService.isViewingSupportTicket(
          _supportData,
          '/support/tickets/$_ticketId',
        ),
        isTrue,
      );
      expect(
        NotificationService.isViewingSupportTicket(
          _supportData,
          '/support/tickets/autre',
        ),
        isFalse,
      );
      expect(
        NotificationService.isViewingSupportTicket(_supportData, '/support'),
        isFalse,
      );
      expect(
        NotificationService.isViewingSupportTicket(_supportData, null),
        isFalse,
      );
      expect(
        NotificationService.isViewingSupportTicket({
          'type': 'NEW_MESSAGE',
          'ticketId': _ticketId,
        }, '/support/tickets/$_ticketId'),
        isFalse,
      );
      expect(
        NotificationService.isViewingSupportTicket({
          'type': 'SUPPORT_MESSAGE',
        }, '/support/tickets/'),
        isFalse,
      );
    });
  });

  group('SUPPORT_MESSAGE au premier plan', () {
    late MockSupportRepository supportRepository;
    late SupportUnreadCubit unreadCubit;
    late SupportLiveEvents liveEvents;
    late List<String> received;

    setUp(() {
      supportRepository = MockSupportRepository();
      when(
        () => supportRepository.loadUnreadCount(),
      ).thenAnswer((_) async => 1);
      unreadCubit = SupportUnreadCubit(supportRepository);
      liveEvents = SupportLiveEvents();
      received = [];
      liveEvents.messages.listen(received.add);
      if (getIt.isRegistered<SupportUnreadCubit>()) {
        getIt.unregister<SupportUnreadCubit>();
      }
      if (getIt.isRegistered<SupportLiveEvents>()) {
        getIt.unregister<SupportLiveEvents>();
      }
      getIt.registerSingleton<SupportUnreadCubit>(unreadCubit);
      getIt.registerSingleton<SupportLiveEvents>(liveEvents);
    });

    tearDown(() async {
      getIt.unregister<SupportUnreadCubit>();
      getIt.unregister<SupportLiveEvents>();
      await unreadCubit.close();
      await liveEvents.dispose();
    });

    test(
      'ailleurs dans l app : bandeau affiché et compteur rafraîchi',
      () async {
        service.currentLocationProvider = () => '/messages';

        final suppressed = service.testHandleSupportForeground(_supportData);
        await pumpEventQueue();

        expect(suppressed, isFalse);
        verify(() => supportRepository.loadUnreadCount()).called(1);
        expect(received, [_ticketId]);
      },
    );

    test('sur la conversation : pas de bandeau, le fil se recharge', () async {
      service.currentLocationProvider = () => '/support/tickets/$_ticketId';

      final suppressed = service.testHandleSupportForeground(_supportData);
      await pumpEventQueue();

      expect(suppressed, isTrue);
      expect(received, [_ticketId]);
      // L'écran de détail resynchronise le compteur après avoir marqué lu.
      verifyNever(() => supportRepository.loadUnreadCount());
    });

    test('sans fournisseur de route : bandeau affiché', () async {
      final suppressed = service.testHandleSupportForeground(_supportData);
      await pumpEventQueue();

      expect(suppressed, isFalse);
    });

    test('un autre type ne touche pas au support', () async {
      final suppressed = service.testHandleSupportForeground({
        'type': 'NEW_MESSAGE',
      });
      await pumpEventQueue();

      expect(suppressed, isFalse);
      expect(received, isEmpty);
      verifyNever(() => supportRepository.loadUnreadCount());
    });
  });
}
