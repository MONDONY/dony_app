import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';

/// Codes ProblemDetail du back (yadony-back, `assistant.formdraft`).
const _quotaExceededCode = 'assistant-form-draft-quota-exceeded';
const _tooManyTurnsCode = 'form-draft-too-many-turns';

class AiFormDraftRepository {
  AiFormDraftRepository(this._api);

  final ApiClient _api;

  /// Envoie tout le dialogue et le brouillon courant : le serveur ne garde
  /// aucune session. Lève un [AiFormDraftException] typé.
  Future<AiFormDraftReply> send({
    required AiFormKind kind,
    required List<AiChatMessage> messages,
    required Map<String, Object?> draft,
    required String locale,
    required DateTime now,
    String? defaultCurrency,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _api.dio.post(
        '/assistant/form-draft/${kind.path}',
        data: {
          'messages': [for (final m in messages) m.toJson()],
          if (draft.isNotEmpty) 'draft': draft,
          'locale': locale,
          'today': isoDate(now),
          'timezone': utcOffsetId(now.timeZoneOffset),
          'defaultCurrency': ?defaultCurrency,
        },
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const AiFormDraftNetworkException();
    }
    try {
      return AiFormDraftReply.fromJson(data);
    } on TypeError {
      throw const AiFormDraftNetworkException();
    }
  }

  /// Les formulaires IA sont-ils allumés pour ce compte ?
  ///
  /// `GET /assistant/status` → `{enabled, formDraftEnabled}`. Champ absent
  /// (back antérieur), erreur ou corps illisible : `false`, pour que la carte
  /// d'entrée n'apparaisse jamais avant le déploiement du back (PR jumelles).
  Future<bool> formDraftEnabled() async {
    try {
      final response = await _api.dio.get('/assistant/status');
      final data = response.data;
      return data is Map &&
          data['enabled'] == true &&
          data['formDraftEnabled'] == true;
    } on Object {
      return false;
    }
  }

  AiFormDraftException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final code = _problemCode(e.response?.data);
    if (status == 404 || status == 403) {
      return const AiFormDraftDisabledException();
    }
    // Une limitation Nginx (corps HTML, sans code) reste une erreur réseau.
    if (status == 429 && code == _quotaExceededCode) {
      return AiFormDraftQuotaExceededException(retryAfter: _retryAfter(e));
    }
    if (status == 422 && code == _tooManyTurnsCode) {
      return const AiFormDraftTooManyTurnsException();
    }
    return const AiFormDraftNetworkException();
  }

  static String? _problemCode(Object? data) {
    if (data is! Map) return null;
    final code = data['code'];
    return code is String ? code : null;
  }

  /// `retryAfter` du ProblemDetail (secondes, ou instant ISO), sinon l'en-tête
  /// `Retry-After` en secondes.
  static Duration? _retryAfter(DioException e) {
    final data = e.response?.data;
    final raw = data is Map ? data['retryAfter'] : null;
    if (raw is num) return Duration(seconds: raw.toInt());
    if (raw is String) {
      final seconds = int.tryParse(raw);
      if (seconds != null) return Duration(seconds: seconds);
      final at = DateTime.tryParse(raw);
      if (at != null) {
        final left = at.difference(DateTime.now());
        return left.isNegative ? Duration.zero : left;
      }
    }
    final header = e.response?.headers.value('retry-after');
    final seconds = header == null ? null : int.tryParse(header);
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
