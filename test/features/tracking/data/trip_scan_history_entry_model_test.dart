import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripScanHistoryEntryModel.fromJson', () {
    test('parses a full entry', () {
      final model = TripScanHistoryEntryModel.fromJson({
        'donNumber': 'TRK000001',
        'recipientName': 'Awa Ndiaye',
        'eventType': 'DEPART',
        'scannedAt': '2026-06-20T14:32:00',
      });

      expect(model.donNumber, 'TRK000001');
      expect(model.recipientName, 'Awa Ndiaye');
      expect(model.eventType, 'DEPART');
      expect(model.scannedAt, DateTime(2026, 6, 20, 14, 32));
    });

    test('donNumber/recipientName null when the bid was deleted', () {
      final model = TripScanHistoryEntryModel.fromJson({
        'donNumber': null,
        'recipientName': null,
        'eventType': 'TRANSIT',
        'scannedAt': '2026-06-20T15:00:00',
      });

      expect(model.donNumber, isNull);
      expect(model.recipientName, isNull);
    });
  });
}
