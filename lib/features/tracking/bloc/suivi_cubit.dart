import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:dony/features/tracking/bloc/scan_hub_cubit.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

/// Les deux usages de l'onglet Suivi. Le nom sert aussi de valeur de
/// requête (`/tracking?mode=valider`) et de propriété analytics.
enum SuiviMode { valider, suivre }

/// Mode demandé par l'URL de l'onglet, `null` si absent ou inconnu.
SuiviMode? suiviModeFromQuery(String? raw) => switch (raw) {
  'valider' => SuiviMode.valider,
  'suivre' => SuiviMode.suivre,
  _ => null,
};

enum SuiviLoadStatus { idle, loading, loaded, error }

/// Verdict sur le numéro de suivi saisi à la remise d'un colis (DEPART).
/// [unverified] : le serveur n'a pas pu répondre (hors ligne) ; la saisie est
/// gardée et il la vérifiera à la réception de l'étape.
enum TrackingNumberCheck { ok, wrong, unverified }

/// Effet ponctuel à jouer par l'écran (navigation, feuille). Chaque émission
/// incrémente [SuiviState.effectId] : l'écran n'écoute que ce compteur.
sealed class SuiviEffect {
  const SuiviEffect();
}

/// Colis du trajet affiché : valider [step].
///
/// - `ARRIVEE` (remise) : parcours photo puis code du destinataire, inchangé.
/// - `TRANSIT` (facultatif, choisi par « Forcer une étape ») lu par QR :
///   validation rapide, sans photo.
/// - Sinon ([photoRequired]) : photo obligatoire d'abord. Sans QR (numéro
///   saisi, bouton d'une ligne colis), la photo est la seule preuve que le
///   colis est entre les mains du voyageur, même pour le transit.
///
/// [confirmNumber] : colis identifié par un numéro saisi, à confirmer sur
/// un récapitulatif avant la photo. Le bouton d'une ligne colis n'en a pas
/// besoin : le voyageur a déjà choisi le colis dans la liste.
final class SuiviValidateStep extends SuiviEffect {
  const SuiviValidateStep(
    this.bid,
    this.step, {
    this.method = ScanMethod.qr,
    this.confirmNumber = false,
  });
  final BidModel bid;
  final String step;
  final ScanMethod method;
  final bool confirmNumber;

  bool get photoRequired => step != 'TRANSIT' || method == ScanMethod.manual;
}

/// Colis du trajet dont une validation attend déjà son envoi.
final class SuiviStepPending extends SuiviEffect {
  const SuiviStepPending(this.bid);
  final BidModel bid;
}

/// Transit ou arrivée forcés sur un colis pas encore parti : le back le
/// refuserait (`depart-required`).
final class SuiviStepNeedsDepart extends SuiviEffect {
  const SuiviStepNeedsDepart(this.bid);
  final BidModel bid;
}

/// Départ ou transit forcés sur un colis où cette [step] est déjà faite.
final class SuiviStepAlreadyDone extends SuiviEffect {
  const SuiviStepAlreadyDone(this.bid, this.step);
  final BidModel bid;
  final String step;
}

/// Colis du trajet affiché dont toutes les étapes sont déjà validées.
final class SuiviStepsAllDone extends SuiviEffect {
  const SuiviStepsAllDone(this.bid);
  final BidModel bid;
}

/// Colis confirmé sur un autre trajet chargé du voyageur.
final class SuiviParcelOnOtherTrip extends SuiviEffect {
  const SuiviParcelOnOtherTrip(this.bid, this.trip);
  final BidModel bid;
  final AnnouncementModel trip;
}

/// Colis absent des trajets du voyageur : il ne peut que suivre son parcours.
final class SuiviParcelUnknown extends SuiviEffect {
  const SuiviParcelUnknown(this.bidId);
  final String bidId;
}

/// Parcours d'un colis en lecture seule.
final class SuiviShowTimeline extends SuiviEffect {
  const SuiviShowTimeline({
    required this.bidId,
    this.departureCity,
    this.arrivalCity,
    this.transportMode,
    this.arrivalInstructions,
    this.trackingNumber,
    this.bidStatus,
    this.bid,
    this.source,
  });
  final String bidId;

  /// Colis quand il est connu de l'app (liste « Mes envois »), `null` pour un
  /// colis d'un tiers retrouvé par numéro ou par QR.
  final BidModel? bid;

  /// D'où vient la demande : `my_shipments`, `qr`, `number`… Seule une ligne
  /// de « Mes envois » propose « Voir le colis » (FLUTTER-7Z).
  final String? source;

  /// Ligne de « Mes envois » : la feuille propose d'ouvrir le colis.
  bool get fromMyShipments => source == 'my_shipments' && bid != null;

  /// Statut du colis quand il est connu de l'app (`ARRIVED` : arrivée
  /// déclarée par le voyageur, sans scan).
  final String? bidStatus;

  /// Numéro DON affiché en tête du parcours, `null` s'il n'est pas connu.
  final String? trackingNumber;

  /// Villes du trajet, `null` quand le colis n'est pas connu de l'app.
  final String? departureCity;
  final String? arrivalCity;

  /// Mode du trajet du voyageur quand il est connu (icône du trajet).
  final TransportMode? transportMode;
  final String? arrivalInstructions;
}

class SuiviState {
  const SuiviState({
    this.canValidate = false,
    this.mode,
    this.busy = false,
    this.shipmentsStatus = SuiviLoadStatus.idle,
    this.shipments = const [],
    this.searchStatus = SuiviLoadStatus.idle,
    this.searchError,
    this.numberStatus = SuiviLoadStatus.idle,
    this.numberError,
    this.forcedStep,
    this.effect,
    this.effectId = 0,
  });

  /// Voyageur : peut valider des étapes et choisir son mode.
  final bool canValidate;

  /// `null` tant que le mode par défaut d'un voyageur attend ses trajets.
  final SuiviMode? mode;

  /// Un scan est en cours de traitement (feuille, parcours photo) : les
  /// détections suivantes sont ignorées et la caméra est en pause.
  final bool busy;

  final SuiviLoadStatus shipmentsStatus;

  /// Envois en cours de l'utilisateur (statuts [kEnvoisEnCours]).
  final List<BidModel> shipments;

  final SuiviLoadStatus searchStatus;
  final AppException? searchError;

  /// Numéro saisi dans la feuille du mode Valider.
  final SuiviLoadStatus numberStatus;
  final AppException? numberError;

  /// Étape imposée au prochain colis scanné ou saisi (« Forcer une
  /// étape » : `DEPART`, `TRANSIT` ou `ARRIVEE`), `null` en automatique.
  final String? forcedStep;

  final SuiviEffect? effect;
  final int effectId;

  SuiviState _copy({
    bool? canValidate,
    SuiviMode? mode,
    bool? busy,
    SuiviLoadStatus? shipmentsStatus,
    List<BidModel>? shipments,
    SuiviLoadStatus? searchStatus,
    AppException? searchError,
    SuiviLoadStatus? numberStatus,
    AppException? numberError,
    String? forcedStep,
    bool clearForcedStep = false,
    SuiviEffect? effect,
  }) => SuiviState(
    canValidate: canValidate ?? this.canValidate,
    mode: mode ?? this.mode,
    busy: busy ?? this.busy,
    shipmentsStatus: shipmentsStatus ?? this.shipmentsStatus,
    shipments: shipments ?? this.shipments,
    searchStatus: searchStatus ?? this.searchStatus,
    // L'erreur suit son statut : effacée dès qu'une recherche repart.
    searchError: searchStatus != null ? searchError : this.searchError,
    numberStatus: numberStatus ?? this.numberStatus,
    numberError: numberStatus != null ? numberError : this.numberError,
    forcedStep: clearForcedStep ? null : forcedStep ?? this.forcedStep,
    effect: effect ?? this.effect,
    effectId: effect != null ? effectId + 1 : effectId,
  );
}

/// Porte l'onglet Suivi : mode, lecture des QR, suivi en lecture seule.
///
/// Les trajets du voyageur restent chargés par [ScanHubCubit] : l'écran
/// passe son état à [resolveDefaultMode] et [onQrScanned].
class SuiviCubit extends Cubit<SuiviState> {
  SuiviCubit(
    this._bidRepo,
    this._trackingRepo,
    this._analytics, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const SuiviState());

  final BidRepository _bidRepo;
  final TrackingRepository _trackingRepo;
  final AnalyticsService _analytics;
  final DateTime Function() _now;

  /// Un QR resté dans le cadre après une feuille fermée ne doit pas la
  /// rouvrir aussitôt : le même colis est ignoré pendant ce délai.
  static const rescanCooldown = Duration(seconds: 3);

  String? _lastBidId;
  DateTime? _releasedAt;

  /// Premier état de l'écran. Un non-voyageur ne peut que suivre ; un
  /// voyageur prend [requested] s'il est fourni, sinon son mode attend ses
  /// trajets ([resolveDefaultMode]).
  void start({required bool canValidate, SuiviMode? requested}) {
    if (!canValidate) {
      emit(state._copy(canValidate: false, mode: SuiviMode.suivre));
      _ensureShipments();
      return;
    }
    emit(state._copy(canValidate: true, mode: requested));
    if (requested == SuiviMode.suivre) _ensureShipments();
  }

  /// Mode par défaut d'un voyageur, une fois ses trajets connus : « Valider »
  /// s'il a au moins un colis à valider (ou si le chargement a échoué, pour
  /// afficher l'erreur et « Réessayer »), « Suivre » sinon.
  ///
  /// Un mode choisi (onglet, URL) ne bouge plus. Un « Suivre » par défaut
  /// passe en « Valider » quand un rechargement fait apparaître un colis à
  /// valider (trajet publié ou demande acceptée depuis) ; jamais l'inverse,
  /// qui ferait sauter l'écran après la dernière validation.
  void resolveDefaultMode(ScanHubState hub) {
    if (!state.canValidate) return;
    if (state.mode != null) {
      if (_modeIsDefault &&
          state.mode == SuiviMode.suivre &&
          hub is ScanHubLoaded &&
          hub.hasParcelToValidate) {
        _setMode(SuiviMode.valider);
      }
      return;
    }
    final mode = switch (hub) {
      ScanHubLoading() => null,
      ScanHubLoaded() =>
        hub.hasParcelToValidate ? SuiviMode.valider : SuiviMode.suivre,
      ScanHubEmpty() => SuiviMode.suivre,
      ScanHubError() => SuiviMode.valider,
    };
    if (mode != null) {
      _modeIsDefault = true;
      _setMode(mode);
    }
  }

  /// Le mode affiché vient de [resolveDefaultMode], pas d'un choix.
  bool _modeIsDefault = false;

  /// Onglet choisi par l'utilisateur.
  void selectMode(SuiviMode mode) {
    if (!state.canValidate || mode == state.mode) return;
    _modeIsDefault = false;
    _logModeChanged(mode);
    _setMode(mode);
  }

  /// Mode imposé par la navigation (`/tracking?mode=…`).
  void applyRequestedMode(SuiviMode? mode) {
    if (mode == null || !state.canValidate || mode == state.mode) return;
    _modeIsDefault = false;
    _setMode(mode);
  }

  void _setMode(SuiviMode mode) {
    emit(state._copy(mode: mode));
    if (mode == SuiviMode.suivre) _ensureShipments();
  }

  void _logModeChanged(SuiviMode mode) => unawaited(
    _analytics.logEvent(
      AnalyticsEvents.suiviModeChanged,
      properties: {'mode': mode.name},
    ),
  );

  void _ensureShipments() {
    if (state.shipmentsStatus == SuiviLoadStatus.loading ||
        state.shipmentsStatus == SuiviLoadStatus.loaded) {
      return;
    }
    unawaited(loadShipments());
  }

  Future<void> loadShipments() async {
    emit(state._copy(shipmentsStatus: SuiviLoadStatus.loading));
    try {
      final bids = await _bidRepo.getMyBids();
      if (isClosed) return;
      emit(
        state._copy(
          shipmentsStatus: SuiviLoadStatus.loaded,
          shipments: bids
              .where((b) => kEnvoisEnCours.contains(b.status))
              .toList(growable: false),
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state._copy(shipmentsStatus: SuiviLoadStatus.error));
    }
  }

  /// Retour sur l'onglet : « Mes envois » déjà affichés sont rafraîchis sans
  /// indicateur de chargement ; un échec garde la liste affichée.
  Future<void> refreshShipments() async {
    if (state.shipmentsStatus != SuiviLoadStatus.loaded) return;
    try {
      final bids = await _bidRepo.getMyBids();
      if (isClosed) return;
      emit(
        state._copy(
          shipments: bids
              .where((b) => kEnvoisEnCours.contains(b.status))
              .toList(growable: false),
        ),
      );
    } catch (_) {
      // Liste précédente conservée : elle reste utilisable.
    }
  }

  /// QR Yadony lu par la caméra de l'onglet (ou le lecteur plein écran de
  /// l'expéditeur, [hub] à `null`). Ignoré pendant un traitement en cours et,
  /// pour le même colis, juste après. [pendingBidIds] : colis dont une
  /// validation attend son envoi.
  void onQrScanned(
    String bidId,
    ScanHubState? hub, {
    Set<String> pendingBidIds = const {},
  }) {
    if (state.busy) return;
    final releasedAt = _releasedAt;
    if (bidId == _lastBidId &&
        releasedAt != null &&
        _now().difference(releasedAt) < rescanCooldown) {
      return;
    }
    _lastBidId = bidId;

    final loaded = hub is ScanHubLoaded ? hub : null;
    final located = loaded == null ? null : _locate(bidId, loaded);
    final String outcome;
    if (located == null) {
      outcome = 'unknown';
    } else if (located.trip.id == loaded!.selectedTripId) {
      outcome = 'own_trip';
    } else {
      outcome = 'other_trip';
    }
    final mode = state.mode ?? SuiviMode.suivre;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.suiviQrScanned,
        properties: {'mode': mode.name, 'outcome': outcome},
      ),
    );

    if (mode == SuiviMode.suivre) {
      _openTimeline(
        bidId,
        source: 'qr',
        bid: located?.bid,
        trip: located?.trip,
      );
      return;
    }
    if (located == null) {
      _emitEffect(SuiviParcelUnknown(bidId));
    } else {
      _emitValidation(
        _validationOf(located, loaded!, ScanMethod.qr, pendingBidIds),
      );
    }
  }

  /// « Forcer une étape » : le prochain colis scanné ou saisi valide [step]
  /// au lieu de son étape automatique.
  void forceStep(String step) => emit(state._copy(forcedStep: step));

  /// Retour à l'étape automatique.
  void clearForcedStep() {
    if (state.forcedStep != null) emit(state._copy(clearForcedStep: true));
  }

  /// Une étape forcée ne sert qu'une fois : elle repasse en automatique dès
  /// qu'un colis est parti en validation.
  void _emitValidation(SuiviEffect effect) => emit(
    state._copy(
      numberStatus: SuiviLoadStatus.idle,
      busy: true,
      effect: effect,
      clearForcedStep: effect is SuiviValidateStep,
    ),
  );

  /// Bouton d'une ligne colis (« Valider le départ », « Valider
  /// l'arrivée ») : [step] tel qu'affiché sur la ligne, sans identification
  /// ni étape forcée. Provenance `MANUAL` : aucun QR n'a été lu.
  void validateParcel(
    BidModel bid,
    String step, {
    Set<String> pendingBidIds = const {},
  }) {
    if (state.busy) return;
    if (pendingBidIds.contains(bid.id)) {
      _emitEffect(SuiviStepPending(bid));
      return;
    }
    _emitEffect(SuiviValidateStep(bid, step, method: ScanMethod.manual));
  }

  /// Effet à jouer pour un colis retrouvé dans les trajets du voyageur.
  SuiviEffect _validationOf(
    ({BidModel bid, AnnouncementModel trip}) located,
    ScanHubLoaded hub,
    ScanMethod method,
    Set<String> pendingBidIds,
  ) {
    final bid = located.bid;
    if (located.trip.id != hub.selectedTripId) {
      return SuiviParcelOnOtherTrip(bid, located.trip);
    }
    final next = nextRequiredStep(bid);
    if (next == null) return SuiviStepsAllDone(bid);
    if (pendingBidIds.contains(bid.id)) return SuiviStepPending(bid);
    final forced = state.forcedStep;
    final progress = colisStepProgress(bid);
    if (forced != null && forced != 'DEPART' && !progress.depart) {
      return SuiviStepNeedsDepart(bid);
    }
    if ((forced == 'DEPART' && progress.depart) ||
        (forced == 'TRANSIT' && progress.transit)) {
      return SuiviStepAlreadyDone(bid, forced!);
    }
    return SuiviValidateStep(
      bid,
      forced ?? next,
      method: method,
      confirmNumber: method == ScanMethod.manual,
    );
  }

  /// Le [number] saisi à la remise est-il bien celui du colis [bidId] ?
  /// Seul l'expéditeur le connaît (FLUTTER-BC).
  Future<TrackingNumberCheck> checkTrackingNumber(
    String bidId,
    String number,
  ) async {
    try {
      final result = await _trackingRepo.searchByTrackingNumber(number);
      return result.bidId == bidId
          ? TrackingNumberCheck.ok
          : TrackingNumberCheck.wrong;
    } catch (e) {
      final error = unwrapDioError(e);
      // Numéro inconnu (404) ou d'un autre colis (403) : refusé. Le reste
      // (réseau coupé, serveur injoignable) ne dit rien du numéro.
      return error is NotFoundException || error is ForbiddenException
          ? TrackingNumberCheck.wrong
          : TrackingNumberCheck.unverified;
    }
  }

  /// Numéro saisi dans la feuille du mode Valider (QR illisible) : le colis
  /// doit être sur le trajet affiché. Cherché d'abord parmi les colis
  /// chargés, puis auprès du back (colis d'un autre voyageur, numéro
  /// inconnu, colis non lié au compte).
  Future<void> validateNumber(
    String raw,
    ScanHubState hub, {
    Set<String> pendingBidIds = const {},
  }) async {
    final number = raw.trim().toUpperCase();
    if (number.isEmpty ||
        hub is! ScanHubLoaded ||
        state.busy ||
        state.numberStatus == SuiviLoadStatus.loading) {
      return;
    }
    var located = _locateByNumber(number, hub);
    if (located == null) {
      emit(state._copy(numberStatus: SuiviLoadStatus.loading));
      try {
        final result = await _trackingRepo.searchByTrackingNumber(number);
        located = _locate(result.bidId, hub);
        if (located == null) {
          emit(
            state._copy(
              numberStatus: SuiviLoadStatus.idle,
              busy: true,
              effect: SuiviParcelUnknown(result.bidId),
            ),
          );
          return;
        }
      } catch (e) {
        emit(
          state._copy(
            numberStatus: SuiviLoadStatus.error,
            numberError: unwrapDioError(e),
          ),
        );
        return;
      }
    }
    _emitValidation(
      _validationOf(located, hub, ScanMethod.manual, pendingBidIds),
    );
  }

  ({BidModel bid, AnnouncementModel trip})? _locateByNumber(
    String number,
    ScanHubLoaded hub,
  ) {
    for (final trip in hub.trips) {
      for (final bid in hub.confirmedBidsOf(trip.id)) {
        if (bid.trackingNumber?.toUpperCase() == number) {
          return (bid: bid, trip: trip);
        }
      }
    }
    return null;
  }

  ({BidModel bid, AnnouncementModel trip})? _locate(
    String bidId,
    ScanHubLoaded hub,
  ) {
    for (final trip in hub.trips) {
      for (final bid in hub.confirmedBidsOf(trip.id)) {
        if (bid.id == bidId) return (bid: bid, trip: trip);
      }
    }
    return null;
  }

  /// « Suivre ce colis » depuis la feuille d'un colis inconnu : bascule en
  /// mode Suivre et ouvre son parcours.
  void followParcel(String bidId) {
    if (state.mode != SuiviMode.suivre) {
      _modeIsDefault = false;
      _logModeChanged(SuiviMode.suivre);
      _setMode(SuiviMode.suivre);
    }
    _openTimeline(bidId, source: 'qr');
  }

  /// Ligne « Mes envois » touchée.
  void trackShipment(BidModel bid) {
    if (state.busy) return;
    _openTimeline(bid.id, source: 'my_shipments', bid: bid);
  }

  /// Saisie modifiée dans le champ du mode Suivre : l'erreur de la recherche
  /// précédente disparaît.
  void clearSearchError() {
    if (state.searchStatus == SuiviLoadStatus.error) {
      emit(state._copy(searchStatus: SuiviLoadStatus.idle));
    }
  }

  /// Saisie modifiée dans le champ du mode Valider : même règle.
  void clearNumberError() {
    if (state.numberStatus == SuiviLoadStatus.error) {
      emit(state._copy(numberStatus: SuiviLoadStatus.idle));
    }
  }

  /// Numéro de suivi saisi : on retrouve le colis puis on ouvre son parcours.
  Future<void> trackNumber(String raw) async {
    final number = raw.trim().toUpperCase();
    if (number.isEmpty ||
        state.busy ||
        state.searchStatus == SuiviLoadStatus.loading) {
      return;
    }
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.suiviTrackSubmitted,
        properties: {'source': 'number'},
      ),
    );
    emit(state._copy(searchStatus: SuiviLoadStatus.loading));
    try {
      final result = await _trackingRepo.searchByTrackingNumber(number);
      emit(
        state._copy(
          searchStatus: SuiviLoadStatus.idle,
          busy: true,
          effect: SuiviShowTimeline(
            bidId: result.bidId,
            departureCity: result.departureCity,
            arrivalCity: result.arrivalCity,
            arrivalInstructions: result.arrivalInstructions,
            trackingNumber: result.trackingNumber,
            source: 'number',
          ),
        ),
      );
    } catch (e) {
      emit(
        state._copy(
          searchStatus: SuiviLoadStatus.error,
          searchError: unwrapDioError(e),
        ),
      );
    }
  }

  void _openTimeline(
    String bidId, {
    required String source,
    BidModel? bid,
    AnnouncementModel? trip,
  }) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.suiviTrackSubmitted,
        properties: {'source': source},
      ),
    );
    final known =
        bid ??
        state.shipments.cast<BidModel?>().firstWhere(
          (b) => b!.id == bidId,
          orElse: () => null,
        );
    final from = known?.departureCity ?? trip?.departureCity;
    final to = known?.arrivalCity ?? trip?.arrivalCity;
    final hasRoute = from != null && to != null;
    _emitEffect(
      SuiviShowTimeline(
        bidId: bidId,
        departureCity: hasRoute ? from : null,
        arrivalCity: hasRoute ? to : null,
        transportMode: trip?.transportMode,
        arrivalInstructions:
            known?.arrivalInstructions ?? trip?.arrivalInstructions,
        trackingNumber: known?.trackingNumber,
        bidStatus: known?.status,
        bid: known,
        source: source,
      ),
    );
  }

  void _emitEffect(SuiviEffect effect) {
    emit(state._copy(busy: true, effect: effect));
  }

  /// L'écran a fini de jouer l'effet (feuille fermée, retour du parcours
  /// photo) : les scans reprennent.
  void releaseScan() {
    _releasedAt = _now();
    if (state.busy) emit(state._copy(busy: false));
  }
}
