import 'package:dio/dio.dart';
import 'package:dony/l10n/l10n.dart';

/// Pose l'en-tête `Accept-Language` sur chaque requête, à partir de la langue
/// effective de l'app ([AppL10n.localeName]) — `fr` ou `en`.
///
/// Placé juste après [OfflineFastFailInterceptor] et avant `_AuthInterceptor`
/// dans [ApiClient] : il ne touche qu'à `onRequest`, jamais au chemin
/// d'erreur, que `_AuthInterceptor` seul rejette et arrête.
class AcceptLanguageInterceptor extends Interceptor {
  AcceptLanguageInterceptor({String Function()? language})
    : _language = language ?? (() => AppL10n.localeName);

  final String Function() _language;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Une seule source de vérité : un en-tête déjà posé par un appelant est
    // remplacé plutôt que conservé.
    options.headers['Accept-Language'] = _language();
    handler.next(options);
  }
}
