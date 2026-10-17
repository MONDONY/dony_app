import 'package:dio/dio.dart';
import 'package:dony/features/gp_pro/data/datasources/gp_pro_remote_datasource.dart';
import 'package:dony/features/gp_pro/data/models/gp_pro_status.dart';

/// Échec d'un appel GP Pro. [code] est le `type` RFC 7807 du back (dernier
/// segment, ex. `gp-pro-application-open`) ou `network` sans réponse.
class GpProException implements Exception {
  const GpProException(this.code, {this.status});

  final String code;
  final int? status;

  @override
  String toString() => 'GpProException($code, status: $status)';
}

/// Le back ne connaît pas `/gp-pro` (déploiement plus ancien que la PR #560).
class GpProUnavailableException extends GpProException {
  const GpProUnavailableException({super.status}) : super('gp-pro-unavailable');
}

class GpProRepository {
  GpProRepository(this._datasource);

  final GpProRemoteDatasource _datasource;

  Future<GpProStatus> fetchStatus() => _guard(_datasource.fetchStatus);

  Future<GpProStatus> apply({
    required GpProFrequency frequency,
    String? commercialName,
    List<String> documentIds = const [],
    required GpProSource source,
  }) => _guard(
    () => _datasource.apply(
      frequency: frequency,
      commercialName: commercialName,
      documentIds: documentIds,
      source: source,
    ),
  );

  Future<GpProDocument> uploadDocument({
    required String filePath,
    required GpProDocType type,
  }) =>
      _guard(() => _datasource.uploadDocument(filePath: filePath, type: type));

  Future<GpProStatus> attachDocuments(List<String> documentIds) =>
      _guard(() => _datasource.attachDocuments(documentIds));

  Future<void> removeDocument(String documentId) =>
      _guard(() => _datasource.removeDocument(documentId));

  Future<void> cancel() => _guard(_datasource.cancel);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  GpProException _map(DioException e) {
    final status = e.response?.statusCode;
    if (e.response == null) return GpProException('network', status: status);
    final code = _problemCode(e.response?.data);
    // 404 sans type gp-pro : route absente, back ancien.
    if (status == 404 && (code == null || !code.startsWith('gp-pro-'))) {
      return GpProUnavailableException(status: status);
    }
    return GpProException(code ?? 'unknown', status: status);
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
