import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/tracking/data/models/traveler_tracking_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('modelParsesMissingFields', () {
    final m = TravelerTrackingModel.fromJson(const {});
    expect(m.status, TravelerTrackingStatus.notActivated);
    expect(m.lastUpdatedAt, isNull);
    expect(m.progressPct, isNull);
    expect(m.nearestCity, isNull);
    expect(m.history, isEmpty);
  });

  test('parses a full payload', () {
    final m = TravelerTrackingModel.fromJson({
      'status': 'EN_ROUTE',
      'lastUpdatedAt': '2026-11-01T10:00:00Z',
      'progressPct': 40,
      'nearestCity': 'Madrid',
      'history': [
        {'city': 'Paris', 'at': '2026-11-01T08:00:00Z'},
        {'city': 'Madrid', 'at': '2026-11-01T10:00:00Z'},
      ],
    });
    expect(m.status, TravelerTrackingStatus.enRoute);
    expect(m.progressPct, 40);
    expect(m.history.map((e) => e.city), ['Paris', 'Madrid']);
    expect(m.history.last.at, isNotNull);
  });

  test('unknown status value falls back to notActivated', () {
    expect(
      TravelerTrackingModel.fromJson(const {'status': 'TELEPORTING'}).status,
      TravelerTrackingStatus.notActivated,
    );
    expect(
      TravelerTrackingModel.fromJson(const {'status': 'STALE'}).status,
      TravelerTrackingStatus.stale,
    );
    expect(
      TravelerTrackingModel.fromJson(const {'status': 'ARRIVED'}).status,
      TravelerTrackingStatus.arrived,
    );
  });

  test('history tolerates malformed entries and missing date', () {
    final m = TravelerTrackingModel.fromJson({
      'history': [
        {'city': 'Paris'},
        {'at': 'x'},
        'bad',
      ],
      'progressPct': 250,
    });
    expect(m.history.length, 1);
    expect(m.history.single.at, isNull);
    expect(m.progressPct, 100);
  });

  test('toJson round trips', () {
    final m = TravelerTrackingModel.fromJson({
      'status': 'ARRIVED',
      'history': [
        {'city': 'Dakar', 'at': '2026-11-01T10:00:00Z'},
      ],
    });
    final back = TravelerTrackingModel.fromJson(m.toJson());
    expect(back.status, TravelerTrackingStatus.arrived);
    expect(back.history.single.city, 'Dakar');
  });

  Map<String, dynamic> announcementJson() => {
    'id': 'a',
    'travelerId': 't',
    'departureCity': 'Paris',
    'arrivalCity': 'Dakar',
    'departureDate': '2026-11-01',
    'availableKg': 1,
    'totalKg': 2,
    'status': 'ACTIVE',
    'createdAt': '2026-10-01T00:00:00Z',
    'updatedAt': '2026-10-01T00:00:00Z',
  };

  test('AnnouncementModel tolerates the old backend', () {
    final a = AnnouncementModel.fromJson(announcementJson());
    expect(a.trackingActive, isFalse);
    expect(a.parcelsSummary, isNull);
  });

  test('AnnouncementModel parses trackingActive and parcelsSummary', () {
    final a = AnnouncementModel.fromJson({
      ...announcementJson(),
      'trackingActive': true,
      'parcelsSummary': {
        'count': 2,
        'totalKg': 3.5,
        'netAmount': 40,
        'currency': 'EUR',
      },
    });
    expect(a.trackingActive, isTrue);
    final s = a.parcelsSummary!;
    expect(
      (s.count, s.totalKg, s.netAmount, s.currency),
      (2, 3.5, 40.0, 'EUR'),
    );
    expect(TripParcelsSummary.fromJson(const {}).count, 0);
    expect(a.toJson()['parcelsSummary'], isA<Map<String, dynamic>>());
  });

  test('BidModel parses travelerTracking, null when absent', () {
    final bid = BidModel.skeleton('b').toJson();
    expect(BidModel.fromJson(bid).travelerTracking, isNull);
    final withTracking = BidModel.fromJson({
      ...bid,
      'travelerTracking': {'status': 'STALE'},
    });
    expect(withTracking.travelerTracking!.status, TravelerTrackingStatus.stale);
  });
}
