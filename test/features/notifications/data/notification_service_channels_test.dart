import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/device_id_service.dart';
import 'package:dony/features/notifications/data/notification_repository.dart';
import 'package:dony/features/notifications/data/notification_service.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockDeviceIdService extends Mock implements DeviceIdService {}

/// Isolé dans son propre fichier : `TestWidgetsFlutterBinding.ensureInitialized()`
/// et le canal de méthode simulé n'ont besoin d'exister que pour ces tests, et
/// initialiser le binding ici plutôt que dans `notification_service_test.dart`
/// évite de changer le comportement des timers/canaux plateforme des tests
/// déjà présents dans ce fichier (device_info_plus, entre autres).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationService service;

  setUp(() {
    service = NotificationService(
      MockApiClient(),
      MockNotificationRepository(),
      MockDeviceIdService(),
    );
  });

  // Régression relecture finale H (Important #2) : `initialize()` crée les
  // canaux Android avant que `AppL10n.syncIntl` n'ait jamais écrit
  // `Intl.defaultLocale`, donc toujours en français, y compris au démarrage
  // suivant. `refreshChannelNames` doit pouvoir les renommer une fois la
  // langue effective connue : Android met à jour le nom d'un canal existant
  // recréé avec le même identifiant.
  group('NotificationService.refreshChannelNames', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    late List<MethodCall> calls;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      // `AndroidFlutterLocalNotificationsPlugin.registerWith()` est normalement
      // appelé par le générateur de plugins au démarrage réel de l'app ; en
      // test, rien n'enregistre l'implémentation avant le premier appel.
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('recrée les deux canaux Android avec les noms traduits', () async {
      await service.refreshChannelNames(lookupAppLocalizations(AppL10n.en));

      final channelCalls = calls
          .where((c) => c.method == 'createNotificationChannel')
          .toList();
      expect(channelCalls, hasLength(2));

      final transactional = channelCalls.firstWhere(
        (c) => (c.arguments as Map)['id'] == 'dony_transactional',
      );
      expect((transactional.arguments as Map)['name'], 'Yadony notifications');

      final general = channelCalls.firstWhere(
        (c) => (c.arguments as Map)['id'] == 'dony_general',
      );
      expect((general.arguments as Map)['name'], 'Yadony news');
    });

    test('rappelée en français renomme les canaux en français', () async {
      await service.refreshChannelNames(lookupAppLocalizations(AppL10n.fr));

      final transactional = calls.firstWhere(
        (c) =>
            c.method == 'createNotificationChannel' &&
            (c.arguments as Map)['id'] == 'dony_transactional',
      );
      expect((transactional.arguments as Map)['name'], 'Notifications Yadony');
    });
  });
}
