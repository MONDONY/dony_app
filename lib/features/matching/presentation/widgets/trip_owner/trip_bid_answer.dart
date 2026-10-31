import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/announcement_state.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_event.dart' as ace;
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart' as acs;
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_list_filter_cubit.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_accept_dispatch.dart';
import 'package:dony/features/matching/presentation/widgets/bid_accept_follow_ups.dart';
import 'package:dony/features/matching/presentation/widgets/commission_allocation_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/reject_reason_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/live_trip.dart';
import 'package:dony/features/tracking/presentation/tracking_consent_prompt.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Réponse en cours à une demande : laquelle, et quel geste.
enum TripBidAnswerAction { accept, reject }

/// Demande [bidId] dont la réponse [action] est partie au serveur.
typedef TripBidAnswering = ({String bidId, TripBidAnswerAction action});

/// Colis du trajet [bids] tels que l'écran les montre après les réponses
/// données depuis l'écran ([answered], [TripBidAnswerController.answered]) :
/// une demande traitée que la liste montre encore en attente (relecture pas
/// revenue, ancienne liste en vol) en est retirée. Une demande traitée que la
/// liste relue montre acceptée y reste : c'est un colis du trajet (compteur
/// Colis, sheet Colis). `null` tant que la liste n'a pas répondu.
///
/// Source unique des compteurs « Activité du trajet », de la carte de réponse
/// directe, du sheet des demandes et du pied « Voir les demandes (N) ».
List<BidModel>? tripBidsAfterAnswers(
  List<BidModel>? bids,
  Set<String> answered,
) => answered.isEmpty
    ? bids
    : bids
          ?.where((b) => !(isPendingBid(b) && answered.contains(b.id)))
          .toList(growable: false);

/// Demandes à traiter de [bids] (`PENDING`, `PAYMENT_ESCROWED`,
/// [isPendingBid]), dans l'ordre reçu, sans celles que le voyageur vient de
/// traiter depuis l'écran ([answered], [tripBidsAfterAnswers]). `null` tant
/// que la liste n'a pas répondu.
List<BidModel>? tripRequestsToAnswer(
  List<BidModel>? bids, [
  Set<String> answered = const {},
]) => tripBidsAfterAnswers(
  bids,
  answered,
)?.where(isPendingBid).toList(growable: false);

/// Répondre aux demandes du trajet depuis son écran (carte « réponse
/// directe » de « À traiter », sheet des demandes), sans passer par la liste
/// des demandes.
abstract interface class TripBidAnswerController {
  /// Réponse partie au serveur, `null` sinon. Une seule à la fois : tant
  /// qu'elle court, tous les boutons Refuser et Accepter sont éteints.
  ValueListenable<TripBidAnswering?> get answering;

  /// Demandes traitées depuis l'écran, ôtées des demandes à traiter
  /// ([tripRequestsToAnswer]) sans attendre la liste relue.
  ValueListenable<Set<String>> get answered;

  /// Demandes dont l'acceptation est refusée pour de bon (trajet complet,
  /// fermé…), avec l'erreur du serveur : « Accepter » y est éteint et le
  /// motif affiché, comme dans `DemandesScreen` (`BidAcceptanceBloc.refusals`,
  /// que le bloc rejouerait sans rappeler le serveur).
  /// Refuser reste possible. Oublié dès que l'écran relit des colis ou un
  /// trajet différents (kilos libérés, statut changé).
  ValueListenable<Map<String, AppException>> get refused;

  /// Accepte [bid] par le parcours habituel du voyageur. [from] : contexte
  /// du bouton touché, d'où partent les messages de la réponse (au-dessus du
  /// sheet des demandes quand il en vient).
  void accept(BidModel bid, {BuildContext? from});

  /// Refuse [bid] après la feuille du motif. [from] : comme [accept].
  void reject(BidModel bid, {BuildContext? from});
}

/// Tient la réponse aux demandes du trajet [tripId] pour tout ce qui est
/// posé dessous ([TripBidAnswerScope.of]) et pour les sheets ouverts depuis
/// l'écran ([TripBidAnswerScope.provide] dans leur `wrapper`).
///
/// Mêmes parcours que l'onglet « À traiter » d'Activité › Demandes, où
/// menait jusqu'ici l'écran du trajet (`DemandesScreen`), sans rien en
/// recopier :
/// - Accepter : explication de la commission répartie
///   ([confirmCashCommissionAllocation]), puis [dispatchBidAccept] (espèces
///   par `BidAcceptanceBloc` avec sa commission, mobile money et carte par
///   `BidBloc`) ;
/// - Refuser : feuille du motif ([RejectReasonSheet]), puis
///   `BidRejectRequested` ;
/// - solde insuffisant : [showBidWalletInsufficientSheet] (recharger, autre
///   portefeuille, carte de commission), relances comprises ;
/// - carte de commission refusée : [showBidCardDeclinedSheet] ;
/// - refus du serveur (409, 422…) : son message ([ErrorPresenter], ou le
///   message du catalogue de `BidFailed`) ; un refus définitif (trajet
///   complet…) éteint « Accepter » de cette demande
///   ([TripBidAnswerController.refused]). Un refus qui montre que la demande
///   a changé (déjà traitée ailleurs, annulée, expirée : 409, 404, 422) fait
///   relire en silence les colis et le trajet : la carte passe à la suivante
///   au lieu de rester bloquée sur une demande qui n'attend plus. Une erreur
///   réseau garde la demande, sans relecture ;
/// - succès : « Demande acceptée ! » ou « Demande refusée. », le
///   consentement au suivi après une acceptation, puis relecture silencieuse
///   des colis et du trajet de l'écran.
///
/// Les réponses passent par des blocs propres au scope, jamais par le
/// `BidBloc` de l'écran : ses états de réponse (chargement, acceptation,
/// erreur) remplaceraient la liste des colis que tout l'écran affiche.
///
/// Les feuilles s'ouvrent depuis le contexte du scope (stable, navigateur
/// racine), jamais celui d'un bouton que la réponse fait disparaître. Les
/// messages (succès, erreurs) partent, eux, du bouton touché tant qu'il est
/// monté : depuis le sheet des demandes, ils s'affichent au-dessus du sheet
/// (`DonySnackbar` d'une feuille au premier plan) au lieu du `Scaffold` de
/// l'écran qu'il recouvre (FLUTTER-4W, FLUTTER-7N). Requiert, au-dessus, le
/// `BidBloc` et l'`AnnouncementBloc` de l'écran pour la relecture (absents :
/// rien n'est relu).
class TripBidAnswerScope extends StatefulWidget {
  const TripBidAnswerScope({
    super.key,
    required this.tripId,
    required this.child,
    this.bidBloc,
    this.acceptanceBloc,
  });

  final String tripId;
  final Widget child;

  /// Blocs de réponse fournis par l'appelant (tests), suivis dès le montage ;
  /// sinon créés par le scope (`getIt`) à la première réponse, et fermés avec
  /// lui. Posé au-dessus de tout l'écran (barre, corps, pied), le scope ne
  /// crée donc aucun bloc pour un visiteur, qui n'a rien à répondre.
  @visibleForTesting
  final BidBloc? bidBloc;
  @visibleForTesting
  final BidAcceptanceBloc? acceptanceBloc;

  /// Contrôleur du scope au-dessus de [context], `null` s'il n'y en a pas.
  static TripBidAnswerController? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_TripBidAnswerInherited>()
      ?.controller;

  /// Contrôleur du scope au-dessus de [context].
  static TripBidAnswerController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'TripBidAnswerScope missing above context');
    return controller!;
  }

  /// Repose [controller] au-dessus de [child] : contenu d'un sheet ouvert
  /// sur le navigateur racine, hors de l'arbre du scope.
  static Widget provide(TripBidAnswerController controller, Widget child) =>
      _TripBidAnswerInherited(controller: controller, child: child);

  @override
  State<TripBidAnswerScope> createState() => _TripBidAnswerScopeState();
}

class _TripBidAnswerInherited extends InheritedWidget {
  const _TripBidAnswerInherited({
    required this.controller,
    required super.child,
  });

  final TripBidAnswerController controller;

  // Contrôleur stable : les widgets suivent ses `ValueListenable`.
  @override
  bool updateShouldNotify(_TripBidAnswerInherited oldWidget) =>
      controller != oldWidget.controller;
}

class _TripBidAnswerScopeState extends State<TripBidAnswerScope>
    implements TripBidAnswerController {
  /// Blocs de réponse, créés à la première réponse ([_ensureBlocs]).
  BidBloc? _bidsOrNull;
  BidAcceptanceBloc? _acceptanceOrNull;

  /// Suivi des blocs de réponse et des blocs de l'écran.
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Empreinte des dernières données de l'écran (colis et statuts, statut et
  /// kilos libres du trajet) : un refus définitif mémorisé ([refused]) est
  /// oublié dès qu'elles changent ([_onScreenData]).
  String? _parcelsPrint;
  String? _tripPrint;

  final _answering = ValueNotifier<TripBidAnswering?>(null);
  final _answered = ValueNotifier<Set<String>>(const {});
  final _refused = ValueNotifier<Map<String, AppException>>(const {});

  /// Une feuille (motif, commission répartie) est ouverte avant l'envoi : un
  /// second appui n'en ouvre pas une autre.
  bool _choosing = false;

  /// Demande de la dernière acceptation espèces lancée : `BidAccepted` du
  /// `BidAcceptanceBloc` ne porte pas d'identifiant.
  String? _cashBidId;

  /// Bouton de la dernière réponse lancée ([accept], [reject]).
  BuildContext? _from;

  /// Contexte des messages de la réponse en cours : le bouton touché tant
  /// qu'il est monté (sheet des demandes au premier plan : message
  /// au-dessus du sheet), sinon le scope.
  BuildContext get _messages {
    final from = _from;
    return from != null && from.mounted ? from : context;
  }

  @override
  ValueListenable<TripBidAnswering?> get answering => _answering;

  @override
  ValueListenable<Set<String>> get answered => _answered;

  @override
  ValueListenable<Map<String, AppException>> get refused => _refused;

  bool get _busy => _choosing || _answering.value != null;

  BidBloc get _bids {
    _ensureBlocs();
    return _bidsOrNull!;
  }

  BidAcceptanceBloc get _acceptance {
    _ensureBlocs();
    return _acceptanceOrNull!;
  }

  @override
  void initState() {
    super.initState();
    if (widget.bidBloc != null || widget.acceptanceBloc != null) {
      _ensureBlocs();
    }
    // Données de l'écran : un refus définitif mémorisé n'est vrai que pour
    // les colis et le trajet qui l'ont vu naître.
    final screenBids = maybeRead<BidBloc>(context);
    if (screenBids != null) {
      _parcelsPrint = _parcelsPrintOf(screenBids.state);
      _subscriptions.add(
        screenBids.stream.listen((state) {
          final next = _parcelsPrintOf(state);
          if (next == null || next == _parcelsPrint) return;
          _parcelsPrint = next;
          _onScreenData();
        }),
      );
    }
    final trips = maybeRead<AnnouncementBloc>(context);
    if (trips != null) {
      _tripPrint = _tripPrintOf(trips.state);
      _subscriptions.add(
        trips.stream.listen((state) {
          final next = _tripPrintOf(state);
          if (next == null || next == _tripPrint) return;
          _tripPrint = next;
          _onScreenData();
        }),
      );
    }
  }

  /// Crée (une fois) les blocs de réponse et les suit, comme un
  /// `BlocListener` : seuls les états émis ensuite comptent.
  void _ensureBlocs() {
    if (_bidsOrNull != null) return;
    final bids = _bidsOrNull = widget.bidBloc ?? getIt<BidBloc>();
    final acceptance = _acceptanceOrNull =
        widget.acceptanceBloc ?? getIt<BidAcceptanceBloc>();
    _subscriptions
      ..add(
        bids.stream.listen((state) {
          if (mounted) _onBidState(state);
        }),
      )
      ..add(
        acceptance.stream.listen((state) {
          if (mounted) _onAcceptanceState(state);
        }),
      );
  }

  /// Empreinte des colis d'un `BidListLoaded`, `null` pour un autre état.
  static String? _parcelsPrintOf(BidState state) => state is BidListLoaded
      ? [for (final b in state.bids) '${b.id}:${b.status}'].join(',')
      : null;

  /// Empreinte du trajet relu, `null` pour un état qui n'en porte pas.
  String? _tripPrintOf(AnnouncementState state) {
    final trip = tripAnnouncementIn(state, widget.tripId);
    return trip == null ? null : '${trip.status}|${trip.availableKg}';
  }

  /// Colis ou trajet relus différents (un colis annulé libère des kilos,
  /// un statut change…) : les refus définitifs mémorisés sont oubliés, ici
  /// et dans le `BidAcceptanceBloc` qui les rejouerait sans appeler le
  /// serveur (comme le « tirer pour rafraîchir » de `DemandesScreen`).
  /// Le serveur redira non si rien n'a changé pour la demande.
  void _onScreenData() {
    if (!mounted) return;
    if (_refused.value.isNotEmpty) _refused.value = const {};
    _acceptanceOrNull?.add(ace.BidAcceptanceRefusalsCleared());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (widget.bidBloc == null) _bidsOrNull?.close();
    if (widget.acceptanceBloc == null) _acceptanceOrNull?.close();
    _answering.dispose();
    _answered.dispose();
    _refused.dispose();
    super.dispose();
  }

  @override
  void accept(BidModel bid, {BuildContext? from}) => _guarded(() async {
    // Espèces réparties sur plusieurs portefeuilles ou converties : le
    // voyageur voit d'où partira la commission avant de s'engager.
    if (!await confirmCashCommissionAllocation(context, bid) || !mounted) {
      return;
    }
    _from = from;
    _answering.value = (bidId: bid.id, action: TripBidAnswerAction.accept);
    if (bid.paymentMethod == BidPaymentMethod.cash) _cashBidId = bid.id;
    dispatchBidAccept(context, bid, bids: _bids, acceptance: _acceptance);
  });

  @override
  void reject(BidModel bid, {BuildContext? from}) => _guarded(() async {
    final reason = await RejectReasonSheet.show(context);
    if (reason == null || !mounted) return;
    _from = from;
    _answering.value = (bidId: bid.id, action: TripBidAnswerAction.reject);
    // bid_rejected est tracé par le BidBloc au succès.
    _bids.add(BidRejectRequested(bid.id, reason: reason.code));
  });

  /// Lance [run] si aucune réponse ni feuille n'est en cours.
  void _guarded(Future<void> Function() run) {
    if (_busy) return;
    _choosing = true;
    unawaited(run().whenComplete(() => _choosing = false));
  }

  void _onBidState(BidState state) {
    switch (state) {
      case BidAccepted(:final bid):
        _answeredOk(bid.id, accepted: true);
      case BidRejected(:final bid):
        _answeredOk(bid.id, accepted: false);
      case BidError(:final error):
        _answering.value = null;
        unawaited(ErrorPresenter.show(_messages, error));
        if (_requestChanged(error)) _reload();
      default:
        break;
    }
  }

  void _onAcceptanceState(acs.BidAcceptanceState state) {
    switch (state) {
      case acs.BidAccepted():
        final id = _cashBidId ?? _answering.value?.bidId;
        _cashBidId = null;
        if (id != null) _answeredOk(id, accepted: true);
      case final acs.BidWalletInsufficient s:
        _answering.value = null;
        showBidWalletInsufficientSheet(
          context,
          s,
          acceptance: _acceptance,
          onRetry: () {
            _cashBidId = s.bidId;
            _answering.value = (
              bidId: s.bidId,
              action: TripBidAnswerAction.accept,
            );
          },
          onCardAdded: _reload,
        );
      case final acs.BidFailed s:
        _answering.value = null;
        final message = s.displayMessage(context.l10n);
        if (s.cardDeclined) {
          showBidCardDeclinedSheet(context, message);
        } else {
          DonySnackbar.show(
            _messages,
            message: message,
            type: DonySnackbarType.error,
          );
        }
        // Refus définitif (trajet complet, fermé…) : « Accepter » de cette
        // demande s'éteint (le bloc rejouerait le même refus), et la liste
        // est sans doute périmée. Un refus du serveur qui montre que la
        // demande a changé la rend périmée aussi.
        if (s.definitive) {
          if ((s.bidId, s.error) case (final id?, final error?)) {
            _refused.value = {..._refused.value, id: error};
          }
          _reload();
        } else if (_requestChanged(s.error)) {
          _reload();
        }
      default:
        break;
    }
  }

  /// Demande [bidId] traitée : elle quitte les demandes à traiter, le
  /// voyageur en est prévenu, l'écran relit ses colis et le trajet.
  void _answeredOk(String bidId, {required bool accepted}) {
    // Message d'abord : le bouton touché (sa ligne) est encore monté.
    final l = context.l10n;
    DonySnackbar.show(
      _messages,
      message: accepted ? l.bidListAcceptedSnackbar : l.bidListRejectedSnackbar,
      type: accepted ? DonySnackbarType.success : DonySnackbarType.info,
    );
    _answering.value = null;
    _answered.value = {..._answered.value, bidId};
    if (accepted) askTrackingConsentAfterAccept(context);
    _reload();
  }

  /// L'erreur [error] vient-elle du serveur et montre-t-elle que la demande
  /// a changé (409 « n'est plus en attente », 404 introuvable, 422 refusée
  /// en l'état) ? Une erreur réseau ou serveur ne prouve rien.
  static bool _requestChanged(Object? error) =>
      error is ConflictException ||
      error is NotFoundException ||
      error is ValidationException;

  /// Relecture silencieuse des colis et du trajet de l'écran : la liste
  /// affichée reste en place, ni indicateur ni erreur.
  void _reload() {
    maybeRead<BidBloc>(
      context,
    )?.add(BidListRequested(widget.tripId, silent: true));
    maybeRead<AnnouncementBloc>(
      context,
    )?.add(AnnouncementDetailRequested(widget.tripId, silent: true));
  }

  @override
  Widget build(BuildContext context) =>
      _TripBidAnswerInherited(controller: this, child: widget.child);
}
