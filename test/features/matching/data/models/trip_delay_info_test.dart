import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json() => {
  'id': 'd1',
  'reason': 'PORT_CONGESTION',
  'arrivalDate': '2026-07-15',
  'arrivalDateMax': '2026-07-25',
  'message': 'Port saturé',
  'announcedAt': '2026-07-01T08:00:00Z',
};

void main() {
  group('TripDelayInfo', () {
    test('tripDelay_parses : contrat réel du back', () {
      final info = TripDelayInfo.fromJsonOrNull(_json())!;
      expect(info.id, 'd1');
      expect(info.reason, 'PORT_CONGESTION');
      expect(info.reasonKind, TripDelayReason.portCongestion);
      expect(info.arrivalDate, DateTime(2026, 7, 15));
      expect(info.arrivalDateMax, DateTime(2026, 7, 25));
      expect(info.message, 'Port saturé');
      expect(info.announcedAt, DateTime.utc(2026, 7, 1, 8));
    });

    test('message absent ou vide : null', () {
      expect(
        TripDelayInfo.fromJsonOrNull(_json()..remove('message'))!.message,
        isNull,
      );
      expect(
        TripDelayInfo.fromJsonOrNull(_json()..['message'] = '  ')!.message,
        isNull,
      );
    });

    test('absent, mal formé ou sans date : null, jamais une exception', () {
      expect(TripDelayInfo.fromJsonOrNull(null), isNull);
      expect(TripDelayInfo.fromJsonOrNull('oops'), isNull);
      expect(TripDelayInfo.fromJsonOrNull(_json()..remove('reason')), isNull);
      expect(
        TripDelayInfo.fromJsonOrNull(_json()..['arrivalDate'] = 'bad'),
        isNull,
      );
      expect(
        TripDelayInfo.fromJsonOrNull(_json()..remove('arrivalDateMax')),
        isNull,
      );
    });

    test('announcedAt illisible : repli sur la nouvelle arrivée', () {
      final info = TripDelayInfo.fromJsonOrNull(
        _json()..['announcedAt'] = null,
      )!;
      expect(info.announcedAt, info.arrivalDate);
    });

    test('motif inconnu : conservé, reasonKind nul', () {
      final info = TripDelayInfo.fromJsonOrNull(_json()..['reason'] = 'NEW')!;
      expect(info.reason, 'NEW');
      expect(info.reasonKind, isNull);
    });

    test('toJson : dates sans heure, relisible', () {
      final info = TripDelayInfo.fromJsonOrNull(_json())!;
      final out = info.toJson();
      expect(out['arrivalDate'], '2026-07-15');
      expect(out['arrivalDateMax'], '2026-07-25');
      expect(TripDelayInfo.fromJsonOrNull(out), info);
      expect(tripDelayToJson(null), isNull);
      expect(tripDelayToJson(info), out);
    });
  });

  group('TripDelayReason', () {
    test('wire aller-retour, inconnu = null', () {
      for (final r in TripDelayReason.values) {
        expect(TripDelayReason.fromWire(r.wire), r);
      }
      expect(TripDelayReason.fromWire('X'), isNull);
      expect(TripDelayReason.fromWire(null), isNull);
    });

    test('PORT_CONGESTION proposé en bateau seulement', () {
      expect(
        TripDelayReason.forMode(TransportMode.boat),
        contains(TripDelayReason.portCongestion),
      );
      for (final mode in [
        TransportMode.plane,
        TransportMode.car,
        TransportMode.bus,
        null,
      ]) {
        final reasons = TripDelayReason.forMode(mode);
        expect(reasons, isNot(contains(TripDelayReason.portCongestion)));
        expect(reasons, contains(TripDelayReason.transportDisruption));
        expect(reasons, contains(TripDelayReason.other));
      }
    });
  });
}
