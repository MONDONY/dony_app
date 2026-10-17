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
    String? parcelId,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _api.dio.post(
        '/assistant/ask',
        data: {
          'question': question,
          'locale': locale,
          'history': history.map((t) => t.toJson()).toList(),
          // Colis choisi plus tôt : le back revérifie l'accès à chaque question.
          'parcelId': ?parcelId,
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
    } on FormatException {
      // Texte de réponse vide ou blanc : même chemin qu'une réponse
      // malformée (« Réessayer »), jamais une bulle vide.
      throw const AssistantNetworkException();
    }
  }

  /// Explication de l'écran [screen] (motif de route) : `null` si aucune fiche
  /// ne l'explique (204), si le back est ancien (404) ou injoignable. Ne lève
  /// jamais : l'assistant s'ouvre alors comme avant.
  Future<AssistantScreenIntro?> screen(String screen, String locale) async {
    try {
      final response = await _api.dio.get(
        '/assistant/screen',
        queryParameters: {'path': screen, 'locale': locale},
      );
      final data = response.data;
      if (response.statusCode == 204 || data is! Map<String, dynamic>) {
        return null;
      }
      return AssistantScreenIntro.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Sonde `GET /assistant/status` : l'assistant est-il allumé pour ce compte ?
  ///
  /// Trois issues, sans jamais lever :
  /// - `true` : 200 `enabled: true` ;
  /// - `false` : 200 `enabled: false`, 403 (invité), 404 (back ancien) ;
  /// - `null` (inconnu) : hors ligne, délai dépassé, 5xx, corps illisible. Le
  ///   BLoC garde alors la valeur précédente au lieu de cacher la bulle sur
  ///   une panne réseau passagère.
  Future<bool?> status() async {
    try {
      final response = await _api.dio.get('/assistant/status');
      final data = response.data;
      if (data is Map && data['enabled'] is bool) {
        return data['enabled'] as bool;
      }
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      return code == 403 || code == 404 ? false : null;
    } catch (_) {
      return null;
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
