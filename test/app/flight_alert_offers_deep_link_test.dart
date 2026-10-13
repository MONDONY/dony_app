import 'package:dony/app/flight_alert_offers_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// `yadony://flights/alerts/{uuid}/offers` : lien d'une notification
/// d'alerte prix vers les vols trouvés. Le segment est validé strictement,
/// comme pour les autres liens paramétrés.
void main() {
  const uuid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

  test('résout un UUID vers les vols trouvés, source notification', () {
    expect(
      resolveFlightAlertOffersDeepLink(
        Uri.parse('yadony://flights/alerts/$uuid/offers'),
      ),
      '/flights/alerts/$uuid/offers?source=notification',
    );
  });

  test('rejette tout autre lien', () {
    for (final link in [
      'https://flights/alerts/$uuid/offers',
      'yadony://bids/alerts/$uuid/offers',
      'yadony://flights/alerts',
      'yadony://flights/alerts/not-a-uuid/offers',
      'yadony://flights/deals/$uuid/offers',
      'yadony://flights/alerts/$uuid/edit',
      'yadony://flights/alerts/$uuid/offers/extra',
    ]) {
      expect(
        resolveFlightAlertOffersDeepLink(Uri.parse(link)),
        isNull,
        reason: link,
      );
    }
  });
}
