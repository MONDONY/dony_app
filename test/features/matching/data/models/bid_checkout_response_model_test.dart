import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BidCheckoutResponseModel', () {
    final expiresAt = DateTime(2030, 12, 31, 23, 59, 59);

    test('constructs correctly', () {
      final model = BidCheckoutResponseModel(
        bidId: 'bid-001',
        clientSecret: 'pi_xxx_secret',
        publishableKey: 'pk_test_xxx',
        expiresAt: expiresAt,
      );

      expect(model.bidId, 'bid-001');
      expect(model.clientSecret, 'pi_xxx_secret');
      expect(model.publishableKey, 'pk_test_xxx');
      expect(model.expiresAt, expiresAt);
    });

    test('fromJson parses correctly', () {
      final json = {
        'bidId': 'bid-001',
        'clientSecret': 'pi_xxx_secret',
        'publishableKey': 'pk_test_xxx',
        'expiresAt': '2030-12-31T23:59:59.000',
      };

      final model = BidCheckoutResponseModel.fromJson(json);

      expect(model.bidId, 'bid-001');
      expect(model.clientSecret, 'pi_xxx_secret');
      expect(model.publishableKey, 'pk_test_xxx');
      expect(model.expiresAt.year, 2030);
    });

    test('fromJson parses the backend payment currency and defaults EUR', () {
      final model = BidCheckoutResponseModel.fromJson({
        'bidId': 'bid-cad',
        'clientSecret': 'pi_cad_secret',
        'publishableKey': 'pk_test_xxx',
        'expiresAt': '2030-12-31T23:59:59.000',
        'currency': 'CAD',
      });
      expect(model.currency, 'CAD');
      expect(
        BidCheckoutResponseModel.fromJson({
          'bidId': 'bid-eur',
          'clientSecret': 'pi_eur_secret',
          'publishableKey': 'pk_test_xxx',
          'expiresAt': '2030-12-31T23:59:59.000',
        }).currency,
        'EUR',
      );
    });

    test('toJson serializes correctly', () {
      final model = BidCheckoutResponseModel(
        bidId: 'bid-002',
        clientSecret: 'pi_yyy_secret',
        publishableKey: 'pk_test_yyy',
        expiresAt: expiresAt,
      );

      final json = model.toJson();

      expect(json['bidId'], 'bid-002');
      expect(json['clientSecret'], 'pi_yyy_secret');
      expect(json['publishableKey'], 'pk_test_yyy');
      expect(json['expiresAt'], isA<String>());
    });

    test('round-trips through JSON', () {
      final original = BidCheckoutResponseModel(
        bidId: 'bid-round',
        clientSecret: 'pi_round_secret',
        publishableKey: 'pk_round',
        expiresAt: DateTime(2031, 1, 1),
      );

      final json = original.toJson();
      final restored = BidCheckoutResponseModel.fromJson(json);

      expect(restored.bidId, original.bidId);
      expect(restored.clientSecret, original.clientSecret);
      expect(restored.publishableKey, original.publishableKey);
    });
  });
}
