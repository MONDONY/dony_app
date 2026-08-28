import 'package:dony/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pro portal URLs', () {
    test('proPortalUpgradeUrl se termine par /upgrade', () {
      expect(proPortalUpgradeUrl(), endsWith('/upgrade'));
    });

    test('proPortalSubscriptionUrl se termine par /parametres/abonnement', () {
      expect(
        proPortalSubscriptionUrl(),
        endsWith('/parametres/abonnement'),
      );
    });

    test('les deux URLs commencent par kProPortalBaseUrl sans double barre', () {
      final upgrade = proPortalUpgradeUrl();
      final subscription = proPortalSubscriptionUrl();

      expect(upgrade.startsWith(kProPortalBaseUrl), isTrue);
      expect(upgrade.startsWith('$kProPortalBaseUrl//'), isFalse);

      expect(subscription.startsWith(kProPortalBaseUrl), isTrue);
      expect(subscription.startsWith('$kProPortalBaseUrl//'), isFalse);
    });
  });
}
