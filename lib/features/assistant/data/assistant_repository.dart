import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/assistant/data/assistant_models.dart';

class AssistantRepository {
  AssistantRepository(this._api);

  final ApiClient _api;

  Future<AssistantAnswer> ask({
    required String question,
    required String locale,
    required List<AssistantHistoryTurn> history,
  }) async {
    try {
      final response = await _api.dio.post(
        '/assistant/ask',
        data: {
          'question': question,
          'locale': locale,
          'history': history.map((t) => t.toJson()).toList(),
        },
      );
      return AssistantAnswer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // 404 : assistant éteint, ou back pas encore déployé (règle des PR
      // jumelles). 403 : invité ou compte sans identifiant, traité comme
      // désactivé pour ne pas afficher une erreur à un compte non éligible.
      final status = e.response?.statusCode;
      if (status == 404 || status == 403) {
        throw const AssistantDisabledException();
      }
      if (status == 429) throw const AssistantQuotaExceededException();
      throw const AssistantNetworkException();
    }
  }
}
