import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// FLUTTER-Q7 : le back envoie ses horodatages en UTC, avec ou sans « Z ». Les
/// modèles les rendent en heure locale, sinon l'historique du portefeuille et
/// les bulles de négociation affichaient l'heure UTC (05:57 au lieu de 07:57).
void main() {
  test('transaction du portefeuille : instant UTC rendu en heure locale', () {
    final tx = WalletTransactionModel.fromJson({
      'type': 'COMMISSION',
      'amount': -2.89,
      'balanceAfter': 6.31,
      'createdAt': '2026-10-15T05:57:00Z',
    });

    expect(tx.createdAt.isUtc, isFalse);
    expect(tx.createdAt, DateTime.utc(2026, 10, 15, 5, 57).toLocal());
  });

  test('message de négociation : LocalDateTime sans fuseau lu comme UTC', () {
    final message = NegotiationMessage.fromJson(const {
      'id': 'm-1',
      'threadId': 't-1',
      'fromUserId': 'u-1',
      'kind': 'COUNTER',
      'proposedPriceEur': 70,
      'createdAt': '2026-10-15T05:50:00',
    });

    expect(message.createdAt.isUtc, isFalse);
    expect(message.createdAt, DateTime.utc(2026, 10, 15, 5, 50).toLocal());
  });
}
