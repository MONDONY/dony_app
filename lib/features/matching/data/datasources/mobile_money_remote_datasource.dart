import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';

class MobileMoneyRemoteDatasource {
  const MobileMoneyRemoteDatasource(this._client);
  final ApiClient _client;

  Future<MobileMoneyPaymentStatus> getStatus(String bidId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/bids/$bidId/mobile-money/status',
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }

  /// Initie (ou relance) une tentative de paiement mobile money. Le numéro
  /// n'est envoyé que s'il est non vide après `trim()` : sans numéro, le
  /// backend réutilise le dernier numéro connu du bid.
  Future<MobileMoneyPaymentStatus> initiate(
    String bidId, {
    String? phoneNumber,
  }) async {
    final trimmed = phoneNumber?.trim();
    final body = (trimmed != null && trimmed.isNotEmpty)
        ? {'phoneNumber': trimmed}
        : null;
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/bids/$bidId/mobile-money/initiate',
      data: body,
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }

  Future<MobileMoneyPaymentStatus> accept(String bidId) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/bids/$bidId/mobile-money/accept',
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }
}
