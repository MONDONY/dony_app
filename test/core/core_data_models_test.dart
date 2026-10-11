import 'package:dony/core/currency/currency_selector.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/network/network_metrics_collector.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

RequestSample _sample({
  String method = 'GET',
  required String path,
  int status = 200,
  required int durationMs,
  int startTsMs = 0,
}) => RequestSample(
  method: method,
  path: path,
  status: status,
  durationMs: durationMs,
  reqBytes: 10,
  respBytes: 90,
  startTsMs: startTsMs,
);

void main() {
  group('CurrencyPaymentOption.fromJson', () {
    test('lit la devise et les rails confirmés par le serveur', () {
      final option = CurrencyPaymentOption.fromJson(const {
        'currency': 'USD',
        'availablePaymentMethods': ['STRIPE', 'CASH', 'MOBILE_MONEY'],
      });
      expect(option.currency, SupportedCurrency.usd);
      expect(option.availablePaymentMethods, {
        BidPaymentMethod.stripe,
        BidPaymentMethod.cash,
        BidPaymentMethod.mobileMoney,
      });
      expect(option.hasCardRail, isTrue);
      expect(option.hasMobileMoneyRail, isTrue);
    });

    test('ignore les moyens inconnus ; liste absente = aucun rail', () {
      final unknown = CurrencyPaymentOption.fromJson(const {
        'currency': 'EUR',
        'availablePaymentMethods': ['BITCOIN', 'CASH'],
      });
      expect(unknown.availablePaymentMethods, {BidPaymentMethod.cash});
      expect(unknown.hasCardRail, isFalse);

      final none = CurrencyPaymentOption.fromJson(const {});
      expect(none.currency, SupportedCurrency.eur);
      expect(none.availablePaymentMethods, isEmpty);
      expect(none.hasMobileMoneyRail, isFalse);
    });
  });

  group('NetworkMetricsCollector.toJson', () {
    test('sérialise les statistiques agrégées par endpoint', () {
      final collector = NetworkMetricsCollector()
        ..record(_sample(path: '/bids/42', durationMs: 100))
        ..record(
          _sample(
            path: '/bids/43',
            durationMs: 300,
            startTsMs: 100,
            status: 500,
          ),
        )
        ..record(_sample(path: '/bids/44', durationMs: 200, startTsMs: 200));

      final json = collector.toJson();
      final endpoints = json['endpoints'] as List;
      expect(endpoints, hasLength(1));
      final e = endpoints.single as Map<String, dynamic>;
      expect(e['key'], 'GET /bids/:id');
      expect(e['count'], 3);
      expect(e['p50'], 200);
      expect(e['p95'], 300);
      expect(e['maxMs'], 300);
      expect(e['totalBytes'], 300);
      expect(e['errorRate'], closeTo(1 / 3, 1e-9));
      expect(e['burst'], isTrue);
    });

    test('clear vide les échantillons', () {
      final collector = NetworkMetricsCollector()
        ..record(_sample(path: '/a', durationMs: 1));
      collector.clear();
      expect(collector.toJson(), {'endpoints': <dynamic>[]});
    });
  });
}
