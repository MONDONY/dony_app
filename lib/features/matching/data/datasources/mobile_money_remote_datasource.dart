import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';

class MobileMoneyRemoteDatasource {
  const MobileMoneyRemoteDatasource(this._client);
  final ApiClient _client;

  Future<MobileMoneyPaymentStatus> getStatus(MobileMoneyScope scope) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      scope.statusPath,
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }

  /// Initie (ou relance) une tentative de paiement mobile money. Le numéro
  /// n'est envoyé que s'il est non vide après `trim()` : sans numéro, le
  /// backend réutilise le dernier numéro connu du bid ou du fil.
  Future<MobileMoneyPaymentStatus> initiate(
    MobileMoneyScope scope, {
    String? phoneNumber,
  }) async {
    final trimmed = phoneNumber?.trim();
    final body = (trimmed != null && trimmed.isNotEmpty)
        ? {'phoneNumber': trimmed}
        : null;
    final response = await _client.dio.post<Map<String, dynamic>>(
      scope.initiatePath,
      data: body,
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }
}
