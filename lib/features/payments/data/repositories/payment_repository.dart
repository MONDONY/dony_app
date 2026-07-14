import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:dony/features/payments/data/models/connect_account_model.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';

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

  /// Clé éphémère Stripe pour la PaymentSheet native (carte). La version
  /// d'API attendue par le SDK natif est appliquée par le datasource
  /// (voir kStripeEphemeralKeyApiVersion dans payment_gateway.dart).
  Future<EphemeralKeyModel> createEphemeralKey() async {
    try {
      return await _datasource.createEphemeralKey();
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
