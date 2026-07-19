import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';

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

  Future<String?> topupStripe({required double amount}) async {
    try {
      final data = await _datasource.topup(
        amount: amount,
        paymentMethod: 'STRIPE',
      );
      return data['clientSecret'] as String?;
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<String?> topupWave({
    required double amount,
    String? countryCode,
    String? phoneNumber,
  }) async {
    try {
      final data = await _datasource.topup(
        amount: amount,
        paymentMethod: 'WAVE',
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );
      return data['redirectUrl'] as String?;
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<String?> topupOrangeMoney({
    required double amount,
    String? countryCode,
    String? phoneNumber,
  }) async {
    try {
      final data = await _datasource.topup(
        amount: amount,
        paymentMethod: 'ORANGE_MONEY',
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );
      return data['redirectUrl'] as String?;
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
