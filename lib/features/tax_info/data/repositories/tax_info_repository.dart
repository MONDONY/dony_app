import 'package:dio/dio.dart';
import 'package:dony/features/tax_info/data/datasources/tax_info_remote_datasource.dart';
import 'package:dony/features/tax_info/data/models/tax_info.dart';

/// Échec d'un appel « informations fiscales ». [code] est le `type` RFC 7807 du
/// back (dernier segment, ex. `tax-info-invalid`) ou `network` sans réponse.
/// Ne porte jamais la valeur saisie.
class TaxInfoException implements Exception {
  const TaxInfoException(this.code, {this.status});

  final String code;
  final int? status;

  @override
  String toString() => 'TaxInfoException($code, status: $status)';
}

/// La fonction est absente pour ce compte : collecte éteinte (404
/// `dac7-disabled`), route inconnue d'un ancien back (404), invité (403) ou
/// session expirée (401). L'app ne montre alors rien du tout.
class TaxInfoUnavailableException extends TaxInfoException {
  const TaxInfoUnavailableException({super.status})
    : super('tax-info-unavailable');
}

class TaxInfoRepository {
  TaxInfoRepository(this._datasource);

  final TaxInfoRemoteDatasource _datasource;

  Future<TaxInfo> fetch() => _guard(_datasource.fetch);

  /// 422 `tax-info-invalid` : numéro refusé par le back.
  Future<TaxInfo> save({
    required String taxIdentificationNumber,
    required String taxCountry,
    String? vatNumber,
  }) => _guard(
    () => _datasource.save(
      taxIdentificationNumber: taxIdentificationNumber,
      taxCountry: taxCountry,
      vatNumber: vatNumber,
    ),
  );

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  TaxInfoException _map(DioException e) {
    final status = e.response?.statusCode;
    if (e.response == null) return TaxInfoException('network', status: status);
    if (status == 404 || status == 403 || status == 401) {
      return TaxInfoUnavailableException(status: status);
    }
    return TaxInfoException(
      _problemCode(e.response?.data) ?? 'unknown',
      status: status,
    );
  }

  /// Dernier segment du `type` RFC 7807, sinon `code` (champ d'extension).
  static String? _problemCode(Object? data) {
    if (data is! Map) return null;
    final type = data['type'];
    if (type is String && type.isNotEmpty) {
      final segment = type.split('/').last;
      if (segment.isNotEmpty) return segment;
    }
    final code = data['code'];
    return code is String && code.isNotEmpty ? code : null;
  }
}
