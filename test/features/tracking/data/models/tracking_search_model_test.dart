import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json([Map<String, dynamic> extra = const {}]) => {
  'trackingNumber': 'DON-ABC123',
  'bidId': 'bid-1',
  'departureCity': 'Marseille',
  'arrivalCity': 'Abidjan',
  'currentStep': 'ACCEPTED',
  'stepLabel': 'Accepté',
  'paymentStatus': 'ESCROWED',
  ...extra,
};

void main() {
  group('TrackingSearchModel.payoutTrigger', () {
    test('DEPOSIT lu', () {
      final m = TrackingSearchModel.fromJson(
        _json({'payoutTrigger': 'DEPOSIT', 'transportMode': 'BOAT'}),
      );
      expect(m.payoutTrigger, PayoutTrigger.deposit);
      expect(m.transportMode, TransportMode.boat);
    });

    test('absent ou inconnu (back antérieur) : livraison', () {
      expect(
        TrackingSearchModel.fromJson(_json()).payoutTrigger,
        PayoutTrigger.delivery,
      );
      expect(
        TrackingSearchModel.fromJson(
          _json({'payoutTrigger': 'AUTRE'}),
        ).payoutTrigger,
        PayoutTrigger.delivery,
      );
      expect(
        TrackingSearchModel.fromJson(
          _json({'payoutTrigger': null}),
        ).payoutTrigger,
        PayoutTrigger.delivery,
      );
    });
  });
}
