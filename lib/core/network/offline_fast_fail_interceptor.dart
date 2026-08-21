import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

/// Échoue une requête sans latence quand l'appareil n'a aucune interface
/// réseau active (avion, wifi/data coupés) — `checkConnectivity()` interroge
/// l'état déjà connu de l'OS, sans aller-retour réseau, donc quasi instantané.
/// Sans cet intercepteur, Dio tenterait quand même une connexion TCP qui
/// n'échouerait qu'après `connectTimeout` (10 s).
///
/// Ne détecte que « aucune interface » : une interface up mais injoignable
/// (wifi captif, serveur en panne) retombe sur le chemin normal
/// (connectTimeout/retry) — impossible à distinguer sans un ping préalable,
/// qui ralentirait aussi chaque requête qui aurait réussi.
class OfflineFastFailInterceptor extends Interceptor {
  OfflineFastFailInterceptor(this._connectivity);

  final Connectivity _connectivity;

  /// Au cold start, `checkConnectivity()` peut renvoyer `none` avant que le
  /// plugin n'ait reçu le premier callback de l'OS (interface pas encore
  /// réassociée après relance de l'app) — sans ces ré-essais, un utilisateur
  /// bel et bien connecté (wifi/4G visibles) tombait sur un écran d'erreur
  /// dès le premier appel. Bornés et courts : le cas réellement hors ligne
  /// ne coûte que ce délai en plus, très inférieur à `connectTimeout` (10 s).
  static const _recheckDelays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 700),
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (await _hasInterface()) {
      handler.next(options);
      return;
    }
    for (final delay in _recheckDelays) {
      await Future<void>.delayed(delay);
      if (await _hasInterface()) {
        handler.next(options);
        return;
      }
    }
    // Retenter via RetryOnTransientErrorInterceptor pendant qu'on est
    // confirmé hors ligne (après les ré-essais ci-dessus) ne fait que
    // retarder l'échec de plusieurs secondes pour rien.
    options.extra['skipTransientRetry'] = true;
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'Aucune connexion réseau',
        message: 'Aucune connexion réseau',
      ),
    );
  }

  Future<bool> _hasInterface() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
