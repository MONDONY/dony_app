import 'dart:async' hide TimeoutException;

import 'package:dony/core/config/cancellation_fee_flag.dart';
import 'package:dony/core/error/app_exception.dart' show TimeoutException;
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/cancellation/data/cancellation_fee_failure.dart';
import 'package:dony/features/cancellation/data/models/cancellation_fee_config_model.dart';
import 'package:dony/features/cancellation/data/repositories/cancellation_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class CancellationFeeConfigState extends Equatable {
  const CancellationFeeConfigState();

  /// Configuration à appliquer aux textes : éteinte tant que rien n'est lu
  /// (back antérieur, hors ligne, lecture ratée).
  CancellationFeeConfigModel get config => CancellationFeeConfigModel.inactive;

  @override
  List<Object?> get props => const [];
}

/// Rien n'a encore été demandé : textes d'avant la fonction.
class CancellationFeeConfigInitial extends CancellationFeeConfigState {
  const CancellationFeeConfigInitial();
}

/// Lecture en cours. Une relecture garde la configuration déjà connue
/// ([previous]) : les textes ne clignotent pas.
class CancellationFeeConfigLoading extends CancellationFeeConfigState {
  const CancellationFeeConfigLoading(this.previous);

  final CancellationFeeConfigModel previous;

  @override
  CancellationFeeConfigModel get config => previous;

  @override
  List<Object?> get props => [previous];
}

class CancellationFeeConfigLoaded extends CancellationFeeConfigState {
  const CancellationFeeConfigLoaded(this.loaded, {required this.fetchedAt});

  final CancellationFeeConfigModel loaded;

  /// Heure de la lecture réussie, pour la relire au bout de
  /// [CancellationFeeConfigCubit.refreshAfter].
  final DateTime fetchedAt;

  @override
  CancellationFeeConfigModel get config => loaded;

  @override
  List<Object?> get props => [loaded, fetchedAt];
}

/// Lecture ratée sans configuration connue : traitée comme éteinte, jamais
/// de message d'erreur. Nouvel essai au prochain besoin, après un délai.
class CancellationFeeConfigUnavailable extends CancellationFeeConfigState {
  const CancellationFeeConfigUnavailable({required this.failedAt});

  final DateTime failedAt;

  @override
  List<Object?> get props => [failedAt];
}

/// État public des frais d'annulation (`GET /config/cancellation-fee`), gardé
/// en mémoire pour la session (singleton paresseux) : les écrans de
/// l'expéditeur y choisissent leurs textes (« des frais d'annulation peuvent
/// s'appliquer »), le catalogue des erreurs et la FAQ lisent son miroir
/// `cancellationFeeActive` (`core/config/cancellation_fee_flag.dart`).
///
/// Lu au premier besoin ([ensureLoaded]), une seule lecture à la fois, relu
/// au bout de [refreshAfter]. Échec : éteint (ou la dernière configuration
/// lue, si une relecture échoue), nouvel essai au prochain besoin passé
/// [retryAfter] ; un back antérieur à la route (404) n'est réinterrogé qu'au
/// bout de [refreshAfter].
class CancellationFeeConfigCubit extends Cubit<CancellationFeeConfigState> {
  CancellationFeeConfigCubit(
    this._repository,
    this._analytics, {
    DateTime Function()? clock,
    Duration timeout = defaultTimeout,
  }) : _clock = clock ?? DateTime.now,
       _timeout = timeout,
       super(const CancellationFeeConfigInitial());

  /// Une configuration, pas une action : inutile d'attendre le délai réseau
  /// complet (30 s et ses relances).
  static const defaultTimeout = Duration(seconds: 8);

  /// Une configuration lue reste valable ce temps-là.
  static const refreshAfter = Duration(minutes: 30);

  /// Délai avant un nouvel essai après un échec (hors ligne, délai, 5xx).
  static const retryAfter = Duration(minutes: 1);

  final CancellationRepository _repository;
  final AnalyticsService _analytics;
  final DateTime Function() _clock;
  final Duration _timeout;
  Future<void>? _inFlight;

  /// Pas de nouvel essai avant cet instant (après un échec).
  DateTime? _retryNotBefore;

  /// Lit la configuration si elle n'est pas connue ou trop ancienne. Rend la
  /// lecture en cours s'il y en a une : jamais deux appels à la fois.
  Future<void> ensureLoaded() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (isClosed) return Future.value();
    final now = _clock();
    final notBefore = _retryNotBefore;
    if (notBefore != null && now.isBefore(notBefore)) return Future.value();
    final current = state;
    if (current is CancellationFeeConfigLoaded &&
        now.difference(current.fetchedAt) < refreshAfter) {
      return Future.value();
    }
    final future = _load().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _load() async {
    final previous = state;
    emit(CancellationFeeConfigLoading(previous.config));
    try {
      final config = await _repository.getFeeConfig().timeout(
        _timeout,
        onTimeout: () => throw const TimeoutException(),
      );
      if (isClosed) return;
      _retryNotBefore = null;
      emit(CancellationFeeConfigLoaded(config, fetchedAt: _clock()));
    } catch (e) {
      if (isClosed) return;
      final notFound = _trackFailure(e);
      final now = _clock();
      _retryNotBefore = now.add(notFound ? refreshAfter : retryAfter);
      // Une relecture ratée garde la configuration déjà lue : basculer sur
      // les textes « sans frais » les rendrait faux.
      emit(
        previous is CancellationFeeConfigLoaded
            ? previous
            : CancellationFeeConfigUnavailable(failedAt: now),
      );
    }
  }

  /// Vrai pour un 404 : back antérieur à la route, cas attendu, jamais
  /// signalé.
  bool _trackFailure(Object e) {
    final code = cancellationFeeFailureCode(e);
    if (code == null) return true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.cancellationFeeConfigFailed,
        properties: {'error_code': code},
      ),
    );
    return false;
  }

  @override
  void onChange(Change<CancellationFeeConfigState> change) {
    super.onChange(change);
    setCancellationFeeActive(change.nextState.config.active);
  }
}
