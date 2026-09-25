import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/presentation/tracking_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  TrackingEventModel event(String type, {double? gpsLat, String? gpsLabel}) =>
      TrackingEventModel(
        id: 'ev-1',
        bidId: 'bid-1',
        eventType: type,
        scannedAt: DateTime(2026, 10, 6, 14, 5),
        createdAt: DateTime(2026, 10, 6, 14, 5),
        gpsLat: gpsLat,
        gpsLon: gpsLat == null ? null : 2.3522,
        gpsLabel: gpsLabel,
      );

  group('TrackingEventL10n.stepLabel', () {
    test('DEPART — fr', () {
      expect(event('DEPART').stepLabel(fr), 'Départ confirmé');
    });
    test('DEPART — en', () {
      expect(event('DEPART').stepLabel(en), 'Departure confirmed');
    });
    test('TRANSIT — fr', () {
      expect(event('TRANSIT').stepLabel(fr), 'En transit');
    });
    test('TRANSIT — en', () {
      expect(event('TRANSIT').stepLabel(en), 'In transit');
    });
    test('ARRIVEE — fr', () {
      expect(event('ARRIVEE').stepLabel(fr), 'Arrivée confirmée');
    });
    test('ARRIVEE — en', () {
      expect(event('ARRIVEE').stepLabel(en), 'Arrival confirmed');
    });
    test('code inconnu — rendu tel quel', () {
      expect(event('CUSTOM_EVENT').stepLabel(fr), 'CUSTOM_EVENT');
    });
  });

  group('TrackingEventL10n.locationLabel', () {
    test('gpsLabel présent — rendu tel quel', () {
      expect(
        event('TRANSIT', gpsLat: 48.8566, gpsLabel: 'Paris').locationLabel(fr),
        'Paris',
      );
    });

    test('gpsLabel vide, coordonnées présentes — repli GPS (fr)', () {
      expect(
        event('TRANSIT', gpsLat: 48.8566).locationLabel(fr),
        'Lieu GPS enregistré',
      );
    });

    test('gpsLabel vide, coordonnées présentes — repli GPS (en)', () {
      expect(
        event('TRANSIT', gpsLat: 48.8566).locationLabel(en),
        'GPS location recorded',
      );
    });

    test('ni gpsLabel ni coordonnées — null', () {
      expect(event('TRANSIT').locationLabel(fr), isNull);
    });
  });
}
