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

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final results = await _connectivity.checkConnectivity();
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (hasInterface) {
      handler.next(options);
      return;
    }
    // Retenter 3 fois avec backoff pendant qu'on est confirmé hors ligne ne
    // fait que retarder l'échec de plusieurs secondes pour rien —
    // `RetryOnTransientErrorInterceptor` classerait sinon ce
    // `connectionError` comme transitoire.
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
}
