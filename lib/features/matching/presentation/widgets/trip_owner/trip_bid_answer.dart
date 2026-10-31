import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/maybe_read.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_bloc.dart';
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
import 'package:dony/features/tracking/presentation/tracking_consent_prompt.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Réponse en cours à une demande : laquelle, et quel geste.
enum TripBidAnswerAction { accept, reject }

/// Demande [bidId] dont la réponse [action] est partie au serveur.
typedef TripBidAnswering = ({String bidId, TripBidAnswerAction action});

/// Demandes à traiter de [bids] (`PENDING`, `PAYMENT_ESCROWED`,
/// [isPendingBid]), dans l'ordre reçu, sans celles que le voyageur vient de
/// traiter depuis l'écran ([answered]) : la liste relue ne les a pas encore
/// retirées. `null` tant que la liste n'a pas répondu.
List<BidModel>? tripRequestsToAnswer(
  List<BidModel>? bids, [
  Set<String> answered = const {},
]) => bids
    ?.where((b) => isPendingBid(b) && !answered.contains(b.id))
    .toList(growable: false);

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

  /// Accepte [bid] par le parcours habituel du voyageur.
  void accept(BidModel bid);

  /// Refuse [bid] après la feuille du motif.
  void reject(BidModel bid);
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
///   message du catalogue de `BidFailed`), la demande reste ; un refus
///   définitif (trajet complet…) relit la liste ;
/// - succès : « Demande acceptée ! » ou « Demande refusée. », le
///   consentement au suivi après une acceptation, puis relecture silencieuse
///   des colis et du trajet de l'écran.
///
/// Les réponses passent par des blocs propres au scope, jamais par le
/// `BidBloc` de l'écran : ses états de réponse (chargement, acceptation,
/// erreur) remplaceraient la liste des colis que tout l'écran affiche.
///
/// Les feuilles s'ouvrent depuis le contexte du scope (stable), jamais celui
/// d'un bouton que la réponse fait disparaître. Requiert, au-dessus, le
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

  /// Blocs de réponse fournis par l'appelant (tests) ; sinon créés par le
  /// scope (`getIt`) et fermés avec lui.
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
  late final BidBloc _bids = widget.bidBloc ?? getIt<BidBloc>();
  late final BidAcceptanceBloc _acceptance =
      widget.acceptanceBloc ?? getIt<BidAcceptanceBloc>();

  final _answering = ValueNotifier<TripBidAnswering?>(null);
  final _answered = ValueNotifier<Set<String>>(const {});

  /// Une feuille (motif, commission répartie) est ouverte avant l'envoi : un
  /// second appui n'en ouvre pas une autre.
  bool _choosing = false;

  /// Demande de la dernière acceptation espèces lancée : `BidAccepted` du
  /// `BidAcceptanceBloc` ne porte pas d'identifiant.
  String? _cashBidId;

  @override
  ValueListenable<TripBidAnswering?> get answering => _answering;

  @override
  ValueListenable<Set<String>> get answered => _answered;

  bool get _busy => _choosing || _answering.value != null;

  @override
  void dispose() {
    if (widget.bidBloc == null) _bids.close();
    if (widget.acceptanceBloc == null) _acceptance.close();
    _answering.dispose();
    _answered.dispose();
    super.dispose();
  }

  @override
  void accept(BidModel bid) => _guarded(() async {
    // Espèces réparties sur plusieurs portefeuilles ou converties : le
    // voyageur voit d'où partira la commission avant de s'engager.
    if (!await confirmCashCommissionAllocation(context, bid) || !mounted) {
      return;
    }
    _answering.value = (bidId: bid.id, action: TripBidAnswerAction.accept);
    if (bid.paymentMethod == BidPaymentMethod.cash) _cashBidId = bid.id;
    dispatchBidAccept(context, bid, bids: _bids, acceptance: _acceptance);
  });

  @override
  void reject(BidModel bid) => _guarded(() async {
    final reason = await RejectReasonSheet.show(context);
    if (reason == null || !mounted) return;
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

  void _onBidState(BuildContext context, BidState state) {
    switch (state) {
      case BidAccepted(:final bid):
        _answeredOk(bid.id, accepted: true);
      case BidRejected(:final bid):
        _answeredOk(bid.id, accepted: false);
      case BidError(:final error):
        _answering.value = null;
        unawaited(ErrorPresenter.show(context, error));
      default:
        break;
    }
  }

  void _onAcceptanceState(BuildContext context, acs.BidAcceptanceState state) {
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
            context,
            message: message,
            type: DonySnackbarType.error,
          );
        }
        // Refus définitif (trajet complet, fermé…) : la liste est sans
        // doute périmée.
        if (s.definitive) _reload();
      default:
        break;
    }
  }

  /// Demande [bidId] traitée : elle quitte les demandes à traiter, le
  /// voyageur en est prévenu, l'écran relit ses colis et le trajet.
  void _answeredOk(String bidId, {required bool accepted}) {
    _answering.value = null;
    _answered.value = {..._answered.value, bidId};
    final l = context.l10n;
    DonySnackbar.show(
      context,
      message: accepted ? l.bidListAcceptedSnackbar : l.bidListRejectedSnackbar,
      type: accepted ? DonySnackbarType.success : DonySnackbarType.info,
    );
    if (accepted) askTrackingConsentAfterAccept(context);
    _reload();
  }

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
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<BidBloc, BidState>(bloc: _bids, listener: _onBidState),
      BlocListener<BidAcceptanceBloc, acs.BidAcceptanceState>(
        bloc: _acceptance,
        listener: _onAcceptanceState,
      ),
    ],
    child: _TripBidAnswerInherited(controller: this, child: widget.child),
  );
}
