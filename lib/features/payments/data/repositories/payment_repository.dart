import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';

class PaymentRepository {
  final PaymentRemoteDatasource _datasource;

  PaymentRepository(this._datasource);

  Future<ConnectAccountModel> createConnectAccount() async {
    try {
      return await _datasource.createConnectAccount();
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<String> createOnboardingLink() async {
    try {
      return await _datasource.createOnboardingLink();
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<PaymentModel> createPayment(String bidId) async {
    try {
      return await _datasource.createPayment(bidId);
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Future<PaymentModel?> getPaymentForBid(String bidId) async {
    try {
      return await _datasource.getPaymentForBid(bidId);
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
