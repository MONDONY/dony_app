import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockDeviceIdService extends Mock implements DeviceIdService {}

void main() {
  late NotificationService service;

  setUp(() {
    service = NotificationService(
      _MockApiClient(),
      _MockNotificationRepository(),
      _MockDeviceIdService(),
    );
  });

  test('foregroundPushStream porte tout le data de la push (bidId)', () async {
    final next = service.foregroundPushStream.first;
    service.emitForegroundPush({'type': 'BID_ACCEPTED', 'bidId': 'bid-1'});
    expect(await next, {'type': 'BID_ACCEPTED', 'bidId': 'bid-1'});
  });

  test('newNotificationStream garde le seul type pour les abonnés', () async {
    final types = service.newNotificationStream.take(2).toList();
    service
      ..emitForegroundPush({'type': 'BID_ACCEPTED', 'bidId': 'bid-1'})
      ..emitForegroundPush({'bidId': 'bid-2'});
    expect(await types, ['BID_ACCEPTED', null]);
  });
}
