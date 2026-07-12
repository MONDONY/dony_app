import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/payments/data/models/saved_card_model.dart';

class PaymentRepository {
  final PaymentRemoteDatasource _datasource;

  PaymentRepository(this._datasource);

  Future<ConnectAccountModel> createConnectAccount() async {
    try {
      return await _datasource.createConnectAccount();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<String> createOnboardingLink() async {
    try {
      return await _datasource.createOnboardingLink();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<ConnectAccountModel> refreshConnectAccount() async {
    try {
      return await _datasource.refreshConnectAccount();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<PaymentModel> createPayment(String bidId) async {
    try {
      return await _datasource.createPayment(bidId);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<PaymentModel?> getPaymentForBid(String bidId) async {
    try {
      return await _datasource.getPaymentForBid(bidId);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<List<SavedCardModel>> listSavedPaymentMethods() async {
    try {
      return await _datasource.listSavedPaymentMethods();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<void> updateSavePaymentMethod(String paymentIntentId, bool save) async {
    try {
      await _datasource.updateSavePaymentMethod(paymentIntentId, save);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
