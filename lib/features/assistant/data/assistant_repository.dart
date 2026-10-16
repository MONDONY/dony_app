import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';

/// Code ProblemDetail du back quand le quota quotidien est atteint.
const _quotaExceededCode = 'assistant-quota-exceeded';

class AssistantRepository {
  AssistantRepository(this._api);

  final ApiClient _api;

  Future<AssistantAnswer> ask({
    required String question,
    required String locale,
    required List<AssistantHistoryTurn> history,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _api.dio.post(
        '/assistant/ask',
        data: {
          'question': question,
          'locale': locale,
          'history': history.map((t) => t.toJson()).toList(),
        },
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
    try {
      return AssistantAnswer.fromJson(response.data as Map<String, dynamic>);
    } on TypeError {
      // Réponse malformée (corps non JSON, champ de mauvais type) : le BLoC ne
      // reçoit jamais une TypeError brute, seulement une erreur typée.
      throw const AssistantNetworkException();
    }
  }

  AssistantException _mapError(DioException e) {
    // 404 : assistant éteint, ou back pas encore déployé (règle des PR
    // jumelles). 403 : invité ou compte sans identifiant, traité comme
    // désactivé pour ne pas afficher une erreur à un compte non éligible.
    final status = e.response?.statusCode;
    if (status == 404 || status == 403) {
      return const AssistantDisabledException();
    }
    // 429 : seulement le quota de l'assistant. Une limitation Nginx (corps
    // HTML ou sans code) reste une erreur réseau.
    if (status == 429 && _problemCode(e.response?.data) == _quotaExceededCode) {
      return const AssistantQuotaExceededException();
    }
    return const AssistantNetworkException();
  }

  /// Lit `code` d'un ProblemDetail, comme `ApiClient.mapHttpError` : corps
  /// Map uniquement.
  static String? _problemCode(Object? data) {
    if (data is! Map) return null;
    final code = data['code'];
    return code is String ? code : null;
  }
}
