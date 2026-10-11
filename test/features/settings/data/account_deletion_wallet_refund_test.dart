import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/settings/data/account_deletion_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

void main() {
  late RecordingApi api;
  late AccountDeletionRepository repo;

  setUp(() {
    api = RecordingApi();
    repo = AccountDeletionRepository(api.client);
  });

  test('requestWalletRefund lit un remboursement par devise', () async {
    api.on('POST', '/auth/me/wallet-refund-request', [
      {'currency': 'EUR', 'amount': 12},
      {'currency': 'XOF', 'amount': 5000.5},
    ]);

    final refunds = await repo.requestWalletRefund();

    expect(api.last.method, 'POST');
    expect(refunds.map((r) => r.currency), ['EUR', 'XOF']);
    expect(refunds.first.amount, 12.0);
    expect(refunds.last.amount, 5000.5);
  });

  test('requestWalletRefund convertit l’erreur serveur', () async {
    api.on('POST', '/auth/me/wallet-refund-request', {
      'code': 'nothing-to-refund',
    }, status: 409);
    await expectLater(repo.requestWalletRefund(), throwsA(isA<AppException>()));
  });
}
