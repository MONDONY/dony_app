import 'package:dony/core/services/trip_bids_events_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diffuse l’identifiant du trajet, ou null', () async {
    final service = TripBidsEventsService();
    final received = <String?>[];
    final sub = service.changes.listen(received.add);
    service.notifyChanged('a1');
    service.notifyChanged();
    await Future<void>.delayed(Duration.zero);
    expect(received, ['a1', null]);
    await sub.cancel();
    await service.dispose();
  });

  test('après dispose, notifyChanged ne lève pas', () async {
    final service = TripBidsEventsService();
    await service.dispose();
    expect(service.notifyChanged, returnsNormally);
  });
}
