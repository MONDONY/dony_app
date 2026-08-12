import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wire maps enum → backend string', () {
    expect(AlertDirection.travelerWantsPackages.wire, 'TRAVELER_WANTS_PACKAGES');
    expect(AlertDirection.senderWantsTrips.wire, 'SENDER_WANTS_TRIPS');
  });

  test('fromWire maps backend string → enum', () {
    expect(AlertDirection.fromWire('TRAVELER_WANTS_PACKAGES'),
        AlertDirection.travelerWantsPackages);
    expect(AlertDirection.fromWire('SENDER_WANTS_TRIPS'),
        AlertDirection.senderWantsTrips);
  });

  test('fromWire defaults to travelerWantsPackages for null/unknown', () {
    expect(AlertDirection.fromWire(null), AlertDirection.travelerWantsPackages);
    expect(AlertDirection.fromWire('GARBAGE'),
        AlertDirection.travelerWantsPackages);
  });
}
