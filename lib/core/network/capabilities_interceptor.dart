import 'package:dio/dio.dart';

/// Annonce au back les fonctions que cette version de l'app sait afficher, sur
/// chaque requête `/conversations*` (liste, archivées, par id, par bid,
/// restauration, archivage, sourdine, lots, ouverture d'une question).
///
/// Le back ne sert les conversations de type `INQUIRY` (question avant
/// réservation) qu'aux clients qui portent `X-Dony-Capabilities: inquiry` :
/// sans l'en-tête, un ancien client ne verrait jamais un fil qu'il ne sait pas
/// ouvrir (liste, archivées et lecture par id les masquent, 403).
///
/// Un seul endroit pour toute la messagerie : un appel ajouté plus tard au
/// dépôt des conversations est couvert sans y penser. Ne touche qu'à
/// `onRequest`, comme `AcceptLanguageInterceptor`.
class CapabilitiesInterceptor extends Interceptor {
  static const headerName = 'X-Dony-Capabilities';
  static const inquiryCapability = 'inquiry';

  /// Préfixe de chemin (relatif à la `baseUrl`) des routes concernées.
  static const pathPrefix = '/conversations';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    if (path == pathPrefix ||
        path.startsWith('$pathPrefix/') ||
        path.startsWith('$pathPrefix?')) {
      options.headers[headerName] = inquiryCapability;
    }
    handler.next(options);
  }
}
