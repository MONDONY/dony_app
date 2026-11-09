import 'package:dony/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bornes de l'intervalle de rafraîchissement Remote Config, en minutes
/// (mêmes que le back : 5 min à 24 h).
const int kRemoteConfigRefreshMinMinutes = 5;
const int kRemoteConfigRefreshMaxMinutes = 1440;

/// Valeur utilisée tant que rien n'est mémorisé (ancien back, premier lancement).
const int kRemoteConfigRefreshDefaultMinutes = 60;

/// Vrai si [minutes] est un intervalle acceptable (entier de 5 à 1440).
bool isValidRemoteConfigRefreshMinutes(Object? minutes) =>
    minutes is int &&
    minutes >= kRemoteConfigRefreshMinMinutes &&
    minutes <= kRemoteConfigRefreshMaxMinutes;

/// Mémoire locale de l'intervalle : Remote Config limite ses lectures par cet
/// intervalle, il faut donc le connaître AVANT de lire.
abstract interface class RemoteConfigIntervalStore {
  /// Dernière valeur mémorisée et valide, sinon `null`.
  Future<int?> read();

  Future<void> write(int minutes);
}

/// Source distante de l'intervalle (`GET /config/remote-config-refresh`).
abstract interface class RemoteConfigIntervalRemote {
  /// Valeur brute du back, `null` si le champ est absent. Lève en cas d'erreur
  /// (404 d'un ancien back, réseau) : l'appelant l'avale.
  Future<Object?> fetchMinutes();
}

final class SharedPrefsRemoteConfigIntervalStore
    implements RemoteConfigIntervalStore {
  SharedPrefsRemoteConfigIntervalStore({
    Future<SharedPreferences> Function()? prefs,
  }) : _prefs = prefs ?? SharedPreferences.getInstance;

  static const _key = 'remote_config_refresh_minutes';

  final Future<SharedPreferences> Function() _prefs;

  @override
  Future<int?> read() async {
    final value = (await _prefs()).getInt(_key);
    return isValidRemoteConfigRefreshMinutes(value) ? value : null;
  }

  @override
  Future<void> write(int minutes) async {
    await (await _prefs()).setInt(_key, minutes);
  }
}

final class ApiRemoteConfigIntervalRemote
    implements RemoteConfigIntervalRemote {
  ApiRemoteConfigIntervalRemote(this._client);

  final ApiClient _client;

  @override
  Future<Object?> fetchMinutes() async {
    final response = await _client.dio.get('/config/remote-config-refresh');
    final data = response.data;
    return data is Map ? data['minutes'] : null;
  }
}
