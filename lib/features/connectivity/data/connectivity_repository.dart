import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

/// Source des deux signaux bruts derrière le bandeau de connectivité global :
/// - le statut réseau OS (wifi/données mobiles/aucun) via connectivity_plus ;
/// - la réactivité réelle de l'API, via un ping court sur `/actuator/health`
///   (même endpoint que `DiagnosticsBloc`).
///
/// Le second signal est nécessaire car une connexion "active" au sens OS
/// (wifi captif, tunnel 3G en falaise de débit, ascenseur) peut rester
/// injoignable ou trop lente — connectivity_plus seul ne le détecte jamais,
/// il ne renseigne que le type d'interface, pas sa qualité.
class ConnectivityRepository {
  ConnectivityRepository(this._connectivity, this._dio);

  final Connectivity _connectivity;
  final Dio _dio;

  /// Délai au-delà duquel l'API est considérée injoignable (connexion "weak").
  static const pingTimeout = Duration(seconds: 4);

  Stream<bool> get onHasConnectionChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  Future<bool> hasConnection() async =>
      _hasConnection(await _connectivity.checkConnectivity());

  static bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// true si l'API répond dans le délai imparti — false si timeout/erreur.
  Future<bool> isApiResponsive() async {
    try {
      await _dio.get(
        '/actuator/health',
        options: Options(sendTimeout: pingTimeout, receiveTimeout: pingTimeout),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
