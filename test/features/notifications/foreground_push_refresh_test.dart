import 'package:dony/features/notifications/foreground_push_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une push reçue application ouverte rechargeait le fil de notifications et
/// les deux listes de l'onglet Activités, quel que soit son type.
void main() {
  group('ForegroundPushRefresh.forType', () {
    test('message de chat : rien, la messagerie a son propre compteur', () {
      final refresh = ForegroundPushRefresh.forType('NEW_MESSAGE');
      expect(refresh.notificationFeed, isFalse);
      expect(refresh.activityIndicators, isFalse);
    });

    test('message support : le fil (il y a une entrée), pas les colis', () {
      final refresh = ForegroundPushRefresh.forType('SUPPORT_MESSAGE');
      expect(refresh.notificationFeed, isTrue);
      expect(refresh.activityIndicators, isFalse);
    });

    test('demande reçue : le fil et les listes de colis', () {
      final refresh = ForegroundPushRefresh.forType('BID_RECEIVED');
      expect(refresh.notificationFeed, isTrue);
      expect(refresh.activityIndicators, isTrue);
    });

    test('type absent : tout, par prudence', () {
      final refresh = ForegroundPushRefresh.forType(null);
      expect(refresh.notificationFeed, isTrue);
      expect(refresh.activityIndicators, isTrue);
    });
  });
}
