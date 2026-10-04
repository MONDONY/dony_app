import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';

/// Étape validée dans l'onglet, pas encore envoyée : « Annuler » reste
/// possible jusqu'à [deadline].
class PendingValidation {
  const PendingValidation({
    required this.id,
    required this.bidId,
    required this.step,
    required this.parcelLabel,
    required this.method,
    required this.deadline,
    this.photoPath,
  });

  final int id;
  final String bidId;

  /// `DEPART` ou `TRANSIT` (l'arrivée passe par le code du destinataire).
  final String step;
  final String parcelLabel;

  /// Comment le colis a été identifié, envoyé au back avec l'étape.
  final ScanMethod method;
  final DateTime deadline;
  final String? photoPath;
}

/// Issue d'un envoi, jouée une fois par l'écran (message, rechargement).
sealed class SuiviValidationOutcome {
  const SuiviValidationOutcome(this.step, this.parcelLabel);
  final String step;
  final String parcelLabel;
}

final class SuiviValidationSent extends SuiviValidationOutcome {
  const SuiviValidationSent(super.step, super.parcelLabel);
}

/// Sans réseau : l'étape attend dans la file hors ligne.
final class SuiviValidationQueued extends SuiviValidationOutcome {
  const SuiviValidationQueued(super.step, super.parcelLabel);
}

final class SuiviValidationFailed extends SuiviValidationOutcome {
  const SuiviValidationFailed(super.step, super.parcelLabel, this.error);
  final AppException error;
}

class SuiviValidationState {
  const SuiviValidationState({
    this.pending = const [],
    this.outcome,
    this.outcomeId = 0,
  });

  /// Du plus ancien au plus récent.
  final List<PendingValidation> pending;
  final SuiviValidationOutcome? outcome;

  /// Incrémenté à chaque [outcome] : l'écran n'écoute que ce compteur.
  final int outcomeId;

  Set<String> get pendingBidIds => {for (final p in pending) p.bidId};
}

/// Validation rapide de l'onglet Suivi : l'étape est affichée comme validée
/// tout de suite, mais ne part qu'au bout de [delay] pour laisser le temps
/// d'« Annuler » (le back n'a pas d'annulation d'événement).
///
/// Chaque validation est écrite dans la file hors ligne Hive dès [schedule],
/// avec une échéance (`notBefore`) : « Annuler » l'en retire, l'envoi
/// ([OfflineSyncService.sendScheduled]) la retire au succès ou au refus du
/// back, et la laisse en file sinon. Quitter l'onglet ou l'app l'envoie
/// aussitôt ([flush]), fermer le cubit aussi ([close]).
///
/// Garantie : une validation qui n'a pas été annulée part au moins une fois,
/// même si le process meurt pendant le délai ou pendant l'envoi : l'entrée
/// restée en file est rejouée par [OfflineSyncService.syncAll] (démarrage,
/// retour du réseau) une fois l'échéance passée. Dans un même process, elle
/// ne part qu'une fois : l'entrée est réservée avant l'appel réseau. Seul un
/// arrêt entre l'acceptation par le back et le retrait de l'entrée la fait
/// rejouer : un départ en double est alors refusé (409, retiré de la file),
/// un transit peut être enregistré deux fois. Une panne réseau, un 5xx ou
/// une session expirée laissent l'entrée en file (issue « en attente »).
class SuiviValidationCubit extends Cubit<SuiviValidationState> {
  SuiviValidationCubit(
    this._queue,
    this._locator,
    this._analytics, {
    this.delay = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SuiviValidationState());

  final OfflineSyncService _queue;
  final ScanLocator _locator;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  /// Délai pendant lequel « Annuler » est possible.
  final Duration delay;

  /// Position attendue au plus ce temps à l'envoi : au-delà, l'étape part
  /// sans elle.
  static const positionTimeout = Duration(seconds: 10);

  /// Ajoutée à l'échéance de l'entrée en file : à la fin du délai, c'est ce
  /// cubit qui l'envoie (avec la position), pas un `syncAll` concurrent.
  static const replayGrace = Duration(seconds: 2);

  final _timers = <int, Timer>{};
  final _positions = <int, Future<ScanPosition?>>{};

  /// Clé Hive de chaque validation, disponible une fois l'écriture faite.
  final _keys = <int, Future<int>>{};
  int _lastId = 0;

  /// Programme l'envoi de [step] pour [bidId]. Sans [position] (validation
  /// sans photo), elle est relevée pendant le délai. Rend l'identifiant de
  /// la validation, `null` si ce colis en a déjà une en attente.
  int? schedule({
    required String bidId,
    required String step,
    required String parcelLabel,
    required ScanMethod method,
    String? photoPath,
    ScanPosition? position,
    String? trackingNumber,
  }) {
    if (isClosed || state.pendingBidIds.contains(bidId)) return null;
    final id = ++_lastId;
    final deadline = _now().add(delay);
    // Écrite tout de suite : un arrêt brutal du process ne la perd plus.
    // Une erreur d'écriture remonte à l'envoi (issue en échec).
    _keys[id] = _queue.queueScan(
      bidId: bidId,
      eventType: step,
      photoPath: photoPath,
      gpsLat: position?.lat,
      gpsLon: position?.lon,
      gpsLabel: position?.label,
      scanMethod: method,
      trackingNumber: trackingNumber,
      notBefore: deadline.add(replayGrace),
    )..ignore();
    _positions[id] = position != null
        ? Future.value(position)
        : _locator.capture();
    _timers[id] = Timer(delay, () => unawaited(_send(id)));
    emit(
      _copy(
        pending: [
          ...state.pending,
          PendingValidation(
            id: id,
            bidId: bidId,
            step: step,
            parcelLabel: parcelLabel,
            method: method,
            deadline: deadline,
            photoPath: photoPath,
          ),
        ],
      ),
    );
    return id;
  }

  /// « Annuler » : rien n'est envoyé.
  void undo(int id) {
    final pending = _find(id);
    if (pending == null) return;
    _timers.remove(id)?.cancel();
    unawaited(_positions.remove(id));
    unawaited(_keys.remove(id)!.then(_queue.discard, onError: (Object _) {}));
    emit(_copy(pending: _without(id)));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.suiviStepUndone,
        properties: {'step': pending.step},
      ),
    );
  }

  /// Envoie tout de suite les validations en attente (onglet quitté, app
  /// en arrière-plan).
  Future<void> flush() =>
      Future.wait([for (final p in state.pending) _send(p.id)]);

  Future<void> _send(int id) async {
    final pending = _find(id);
    if (pending == null) return;
    _timers.remove(id)?.cancel();
    final position = _positions.remove(id)!;
    final key = _keys.remove(id)!;
    if (!isClosed) emit(_copy(pending: _without(id)));

    SuiviValidationOutcome outcome;
    try {
      final event = await _queue.sendScheduled(
        await key,
        position: _positionOrNull(position),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.suiviStepValidated,
          properties: {'step': pending.step, 'method': pending.method.name},
        ),
      );
      outcome = event != null
          ? SuiviValidationSent(pending.step, pending.parcelLabel)
          : SuiviValidationQueued(pending.step, pending.parcelLabel);
    } catch (e) {
      outcome = SuiviValidationFailed(
        pending.step,
        pending.parcelLabel,
        unwrapDioError(e),
      );
    }
    if (!isClosed) {
      emit(
        SuiviValidationState(
          pending: state.pending,
          outcome: outcome,
          outcomeId: state.outcomeId + 1,
        ),
      );
    }
  }

  /// Position relevée, ou `null` si elle échoue ou tarde plus que
  /// [positionTimeout].
  Future<ScanPosition?> _positionOrNull(Future<ScanPosition?> position) async {
    try {
      return await position.timeout(positionTimeout);
    } catch (_) {
      return null;
    }
  }

  PendingValidation? _find(int id) {
    for (final p in state.pending) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<PendingValidation> _without(int id) =>
      state.pending.where((p) => p.id != id).toList(growable: false);

  SuiviValidationState _copy({required List<PendingValidation> pending}) =>
      SuiviValidationState(
        pending: pending,
        outcome: state.outcome,
        outcomeId: state.outcomeId,
      );

  /// Fermé avec des validations en attente (onglet démonté) : elles partent
  /// quand même, sans message à l'écran.
  @override
  Future<void> close() {
    for (final p in state.pending) {
      unawaited(_send(p.id));
    }
    return super.close();
  }
}
