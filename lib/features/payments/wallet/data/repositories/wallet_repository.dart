import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_eligible_topup_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';

class WalletRepository {
  final WalletRemoteDatasource _datasource;

  WalletRepository(this._datasource);

  Future<WalletModel> getBalance() async {
    try {
      return await _datasource.getBalance();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<String?> topupStripe({
    required double amount,
    String currencyCode = 'EUR',
  }) async {
    try {
      final data = await _datasource.topup(
        amount: amount,
        paymentMethod: 'STRIPE',
        currencyCode: currencyCode,
      );
      return data['clientSecret'] as String?;
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<List<WalletEligibleTopupModel>> getRefundEligibleTopups(
    String currency,
  ) async {
    try {
      final data = await _datasource.getRefundEligibleTopups(currency);
      return data
          .map(
            (e) => WalletEligibleTopupModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<WalletRefundRequestModel> requestRefund(
    String currency,
    List<String> transactionIds,
  ) async {
    try {
      final data = await _datasource.requestRefund(currency, transactionIds);
      return WalletRefundRequestModel.fromJson(data);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<List<WalletRefundRequestModel>> getRefundRequests() async {
    try {
      final data = await _datasource.getRefundRequests();
      return data
          .map(
            (e) => WalletRefundRequestModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
