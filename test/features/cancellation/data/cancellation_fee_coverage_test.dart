import 'package:dony/features/cancellation/data/cancellation_fee_coverage.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _from = DateTime.utc(2026, 12, 15);

final _active = CancellationFeeConfigModel(active: true, effectiveFrom: _from);

BidModel _bid({
  DateTime? createdAt,
  BidPaymentMethod method = BidPaymentMethod.stripe,
}) => BidModel(
  id: 'bid-1',
  announcementId: 'ann-1',
  senderId: 'sender-1',
  status: 'ACCEPTED',
  paymentMethod: method,
  createdAt: createdAt ?? DateTime.utc(2026, 12, 20),
  updatedAt: DateTime.utc(2026, 12, 20),
);

void main() {
  group('isCoveredByCancellationFee', () {
    test('frais éteints : jamais couvert', () {
      expect(
        isCoveredByCancellationFee(_bid(), CancellationFeeConfigModel.inactive),
        isFalse,
      );
    });

    test('allumé sans date d\'effet (modèle construit à la main) : non '
        'couvert', () {
      expect(
        isCoveredByCancellationFee(
          _bid(),
          const CancellationFeeConfigModel(active: true),
        ),
        isFalse,
      );
    });

    test('colis créé avant la date d\'effet : non couvert', () {
      expect(
        isCoveredByCancellationFee(
          _bid(createdAt: DateTime.utc(2026, 12, 14, 23, 59, 59)),
          _active,
        ),
        isFalse,
      );
    });

    test('colis créé pile à la date d\'effet, ou après : couvert', () {
      expect(
        isCoveredByCancellationFee(_bid(createdAt: _from), _active),
        isTrue,
      );
      expect(
        isCoveredByCancellationFee(
          _bid(createdAt: DateTime.utc(2027, 1, 3)),
          _active,
        ),
        isTrue,
      );
    });

    test('date du back sans fuseau (LocalDateTime UTC) : relue en UTC', () {
      // `2026-12-15T00:30:00` sans suffixe : Dart la lit en heure locale,
      // le serveur la compare en UTC. 00:30 UTC est après la date d'effet,
      // 23:30 UTC la veille est avant, quel que soit le fuseau du téléphone.
      expect(
        isCoveredByCancellationFee(
          _bid(createdAt: DateTime.parse('2026-12-15T00:30:00')),
          _active,
        ),
        isTrue,
      );
      expect(
        isCoveredByCancellationFee(
          _bid(createdAt: DateTime.parse('2026-12-14T23:30:00')),
          _active,
        ),
        isFalse,
      );
    });

    test('carte et mobile money : couverts ; espèces et modes historiques : '
        'jamais', () {
      final expected = {
        BidPaymentMethod.stripe: true,
        BidPaymentMethod.mobileMoney: true,
        BidPaymentMethod.cash: false,
        BidPaymentMethod.wave: false,
        BidPaymentMethod.orangeMoney: false,
      };
      for (final MapEntry(key: method, value: covered) in expected.entries) {
        expect(
          isCoveredByCancellationFee(_bid(method: method), _active),
          covered,
          reason: method.name,
        );
      }
    });

    test('date de création inconnue (colis squelette, époque Unix) : non '
        'couvert', () {
      expect(
        isCoveredByCancellationFee(BidModel.skeleton('bid-1'), _active),
        isFalse,
      );
      expect(
        isCoveredByCancellationFee(
          _bid(createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
          _active,
        ),
        isFalse,
      );
    });
  });
}
