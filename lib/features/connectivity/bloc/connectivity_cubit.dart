import 'dart:async';

import 'package:dony/features/connectivity/bloc/connectivity_state.dart';
import 'package:dony/features/connectivity/data/connectivity_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pilote le bandeau de statut réseau global (cf. `ConnectivityBanner`).
///
/// Le `Timer.periodic` interne n'a qu'un rôle : rappeler [checkNow]
/// périodiquement. Les tests appellent [checkNow] et [clearReconnectedFlag]
/// directement, sans jamais attendre un vrai Timer — même principe que
/// `AuthBloc._onOtpTimerTicked` (le Timer déclenche un événement/méthode
/// public que les tests invoquent eux-mêmes).
class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit(this._repository) : super(const ConnectivityState()) {
    _init();
  }

  final ConnectivityRepository _repository;

  /// Cadence de la sonde quand tout va bien — coût réseau minimal.
  static const healthyProbeInterval = Duration(seconds: 20);

  /// Cadence resserrée pendant un incident, pour détecter le retour vite.
  static const degradedProbeInterval = Duration(seconds: 5);

  /// Durée d'affichage du bandeau vert de confirmation après reconnexion.
  static const reconnectedFlashDuration = Duration(milliseconds: 2500);

  StreamSubscription<bool>? _connectivitySub;
  Timer? _probeTimer;
  Timer? _reconnectedFlashTimer;
  Duration? _currentProbeInterval;

  Future<void> _init() async {
    final hasConnection = await _repository.hasConnection();
    if (hasConnection) {
      _ensureProbeInterval(healthyProbeInterval);
    } else {
      emit(state.copyWith(status: ConnectivityStatus.offline));
      _ensureProbeInterval(degradedProbeInterval);
    }
    _connectivitySub =
        _repository.onHasConnectionChanged.listen(_onDeviceConnectivityChanged);
  }

  void _onDeviceConnectivityChanged(bool hasConnection) {
    if (!hasConnection) {
      _reconnectedFlashTimer?.cancel();
      emit(state.copyWith(
        status: ConnectivityStatus.offline,
        justReconnected: false,
      ));
      _ensureProbeInterval(degradedProbeInterval);
      return;
    }
    // Le device signale une connexion active — reste à vérifier qu'elle est
    // exploitable avant d'annoncer un vrai retour (cf. checkNow).
    checkNow();
  }

  /// Une itération de la sonde : re-vérifie la connectivité device PUIS la
  /// réactivité API. Publique : appelée par le Timer interne comme par les
  /// tests.
  ///
  /// Re-vérifier la connectivité device ici (et pas seulement réagir au
  /// stream [onHasConnectionChanged]) est nécessaire : `connectivity_plus`
  /// ne pousse un événement qu'au moment d'un changement réel, jamais pour
  /// confirmer l'état courant. Si le tout premier appel de [_init] tombe sur
  /// un faux négatif (race connue au cold-start Android — l'OS n'a pas
  /// encore fini de résoudre l'état réseau), et que la connexion ne change
  /// plus jamais après, le bandeau restait bloqué en offline pour toujours
  /// puisque plus aucun événement ne survient pour le corriger. La sonde
  /// périodique (déclenchée même en offline, cf. [_ensureProbeInterval]
  /// appelé ci-dessous) rejoue ce même check toutes les [degradedProbeInterval]
  /// et se corrige donc d'elle-même.
  Future<void> checkNow() async {
    final hasConnection = await _repository.hasConnection();
    if (!hasConnection) {
      if (state.status != ConnectivityStatus.offline) {
        emit(state.copyWith(
          status: ConnectivityStatus.offline,
          justReconnected: false,
        ));
      }
      _ensureProbeInterval(degradedProbeInterval);
      return;
    }

    final responsive = await _repository.isApiResponsive();

    if (responsive) {
      final wasDegraded = state.status != ConnectivityStatus.online;
      if (wasDegraded) {
        _reconnectedFlashTimer?.cancel();
        emit(state.copyWith(
          status: ConnectivityStatus.online,
          justReconnected: true,
        ));
        _reconnectedFlashTimer =
            Timer(reconnectedFlashDuration, clearReconnectedFlag);
      }
      _ensureProbeInterval(healthyProbeInterval);
    } else {
      if (state.status != ConnectivityStatus.weak) {
        emit(state.copyWith(
          status: ConnectivityStatus.weak,
          justReconnected: false,
        ));
      }
      _ensureProbeInterval(degradedProbeInterval);
    }
  }

  /// Masque le bandeau vert de confirmation. Public pour que le Timer interne
  /// et les tests appellent exactement le même chemin.
  void clearReconnectedFlag() {
    if (state.justReconnected) {
      emit(state.copyWith(justReconnected: false));
    }
  }

  void _ensureProbeInterval(Duration interval) {
    if (_probeTimer != null && _currentProbeInterval == interval) {
      return;
    }
    _currentProbeInterval = interval;
    _probeTimer?.cancel();
    _probeTimer = Timer.periodic(interval, (_) => checkNow());
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    _probeTimer?.cancel();
    _reconnectedFlashTimer?.cancel();
    return super.close();
  }
}
