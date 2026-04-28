import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrackingEventModel', () {
    final baseJson = {
      'id': 'ev-1',
      'bidId': 'bid-1',
      'eventType': 'TRANSIT',
      'scannedAt': '2024-01-15T10:00:00Z',
      'gpsLat': 48.8566,
      'gpsLon': 2.3522,
      'photoUrl': 'https://cdn.dony.app/photo.jpg',
      'offlineTimestamp': '2024-01-15T09:55:00Z',
      'createdAt': '2024-01-15T10:00:05Z',
    };

    test('fromJson parses all fields correctly', () {
      final model = TrackingEventModel.fromJson(baseJson);
      expect(model.id, 'ev-1');
      expect(model.bidId, 'bid-1');
      expect(model.eventType, 'TRANSIT');
      expect(model.gpsLat, 48.8566);
      expect(model.gpsLon, 2.3522);
      expect(model.photoUrl, 'https://cdn.dony.app/photo.jpg');
      expect(model.offlineTimestamp, isNotNull);
    });

    test('fromJson handles null optional fields', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['gpsLat'] = null
        ..['gpsLon'] = null
        ..['photoUrl'] = null
        ..['offlineTimestamp'] = null;
      final model = TrackingEventModel.fromJson(json);
      expect(model.gpsLat, isNull);
      expect(model.gpsLon, isNull);
      expect(model.photoUrl, isNull);
      expect(model.offlineTimestamp, isNull);
    });

    test('stepLabel returns Départ confirmé for DEPART', () {
      final model = TrackingEventModel.fromJson({
        ...baseJson,
        'eventType': 'DEPART',
      });
      expect(model.stepLabel, 'Départ confirmé');
    });

    test('stepLabel returns En transit for TRANSIT', () {
      final model = TrackingEventModel.fromJson(baseJson);
      expect(model.stepLabel, 'En transit');
    });

    test('stepLabel returns Arrivée confirmée for ARRIVEE', () {
      final model = TrackingEventModel.fromJson({
        ...baseJson,
        'eventType': 'ARRIVEE',
      });
      expect(model.stepLabel, 'Arrivée confirmée');
    });

    test('stepLabel falls back to eventType for unknown', () {
      final model = TrackingEventModel.fromJson({
        ...baseJson,
        'eventType': 'CUSTOM_EVENT',
      });
      expect(model.stepLabel, 'CUSTOM_EVENT');
    });
  });

  group('TrackingSearchModel', () {
    final json = {
      'trackingNumber': 'DON-A1B2C3',
      'bidId': 'bid-42',
      'departureCity': 'Paris',
      'arrivalCity': 'Dakar',
      'currentStep': 'IN_TRANSIT',
      'stepLabel': 'En transit',
      'paymentStatus': 'CAPTURED',
    };

    test('fromJson parses all fields', () {
      final model = TrackingSearchModel.fromJson(json);
      expect(model.trackingNumber, 'DON-A1B2C3');
      expect(model.bidId, 'bid-42');
      expect(model.departureCity, 'Paris');
      expect(model.arrivalCity, 'Dakar');
      expect(model.currentStep, 'IN_TRANSIT');
      expect(model.stepLabel, 'En transit');
      expect(model.paymentStatus, 'CAPTURED');
    });
  });

  group('QrCodeModel', () {
    final json = {
      'bidId': 'bid-7',
      'scanUrl': 'https://api.dony.app/scan/abc',
      'qrCodeBase64': 'base64data==',
    };

    test('fromJson parses all fields', () {
      final model = QrCodeModel.fromJson(json);
      expect(model.bidId, 'bid-7');
      expect(model.scanUrl, 'https://api.dony.app/scan/abc');
      expect(model.qrCodeBase64, 'base64data==');
    });
  });
}
