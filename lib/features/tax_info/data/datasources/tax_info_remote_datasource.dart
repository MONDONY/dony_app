import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';
import 'package:dony/features/tax_info/data/models/tax_info_update.dart';

/// Appels API `/travelers/me/tax-info` (yadony-back lot 3a DAC7, PR #726).
class TaxInfoRemoteDatasource {
  TaxInfoRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  static const _path = '/travelers/me/tax-info';

  Future<TaxInfo> fetch() async {
    final response = await _apiClient.dio.get(_path);
    return TaxInfo.fromJson(response.data as Map<String, dynamic>);
  }

  /// `vatNumber` n'est envoyé que s'il est renseigné.
  Future<TaxInfo> save({
    required String taxIdentificationNumber,
    required String taxCountry,
    String? vatNumber,
  }) async {
    final vat = vatNumber?.trim();
    final response = await _apiClient.dio.put(
      _path,
      data: {
        'taxIdentificationNumber': taxIdentificationNumber.trim(),
        'taxCountry': taxCountry,
        if (vat != null && vat.isNotEmpty) 'vatNumber': vat,
      },
    );
    return TaxInfo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Collecte ciblée (yadony-back #730) : n'envoie que les champs présents.
  Future<TaxInfo> update(TaxInfoUpdate update) async {
    final response = await _apiClient.dio.put(_path, data: update.toJson());
    return TaxInfo.fromJson(response.data as Map<String, dynamic>);
  }
}
