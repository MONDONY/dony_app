import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_rejection_reason.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/open_trip_validation.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/retrait_code_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/return_code_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_blocked_code_block.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_code_renewal_request_block.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:dony/features/matching/presentation/widgets/reject_reason_sheet.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Zone action + bande de suivi du talon bas du billet de colis.
///
/// Dispatcher : selon [bid.status] × [isSender], affiche le bon contenu
/// d'action (QR, code retrait, scan, confirmation, placeholder, done…).
/// Si le numéro de suivi est visible, la [TalonTrackingStrip] est toujours
/// ajoutée en bas, quelle que soit l'action. L'expéditeur le voit dès qu'il
/// existe ; le voyageur seulement à partir de la remise
/// ([travelerVisibleTrackingNumber]).
///
/// NOTE : les boutons [_QrTalonButton] et [_RetraitTalonButton] ouvrent
/// respectivement la [QrSheet] et la [RetraitCodeSheet] ; les BLoCs ambiants
/// (TrackingBloc / BidBloc) sont fournis par l'écran parent. Ce widget
/// n'injecte aucun [BlocProvider].
class BilletTalon extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const BilletTalon({super.key, required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Le voyageur ne voit le numéro de suivi qu'à partir de la remise.
    final trackingNumber = isSender
        ? bid.trackingNumber
        : travelerVisibleTrackingNumber(bid);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(DonyRadius.card),
          bottomRight: Radius.circular(DonyRadius.card),
        ),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionZone(context),
          if (trackingNumber != null) ...[
            const SizedBox(height: DonySpacing.md),
            TalonTrackingStrip(
              trackingNumber: trackingNumber,
              trackingToken: bid.trackingToken,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionZone(BuildContext context) {
    final status = bid.status;

    // ── Sender dispatch ───────────────────────────────────────────────────────
    if (isSender) {
      return switch (status) {
        // Carte pas encore payée : c'est à l'expéditeur d'agir (FLUTTER-G7).
        'PENDING' when bid.isAwaitingSenderCardPayment =>
          const _PendingPlaceholder(awaitingMyPayment: true),
        'PENDING' || 'PAYMENT_ESCROWED' => const _PendingPlaceholder(),
        // Offre mobile money acceptée par le voyageur : c'est à l'expéditeur
        // de payer (30 min), via « Payer par mobile money » dans la barre
        // collante. Le placeholder « en attente du voyageur » serait faux ici.
        'AWAITING_PAYMENT'
            when bid.paymentMethod == BidPaymentMethod.mobileMoney =>
          const _SenderAwaitingPaymentBlock(),
        'AWAITING_PAYMENT' => const _PendingPlaceholder(),
        'ACCEPTED' => _QrTalonButton(bid: bid),
        // Le code de retrait existe dès la remise (HANDED_OVER). Comme le QR,
        // il s'ouvre dans un bottom sheet : deux boutons côte à côte dans le
        // talon, le QR restant accessible jusqu'au retrait.
        // ARRIVED (voyageur arrivé à destination) se comporte comme IN_TRANSIT :
        // c'est justement le moment où le code de retrait sert le plus.
        // Un code expiré mais encore présent compte comme absent : le
        // voyageur ne peut plus s'en servir (FLUTTER-G2).
        'HANDED_OVER' ||
        'IN_TRANSIT' ||
        'ARRIVED' when !bid.needsNewPickupCode => Row(
          children: [
            Expanded(child: _QrTalonButton(bid: bid, compact: true)),
            const SizedBox(width: DonySpacing.sm),
            Expanded(child: _RetraitTalonButton(bid: bid)),
          ],
        ),
        // Colis remis sans code : le serveur l'a effacé après trois essais
        // faux du voyageur, ou à l'expiration (FLUTTER-G1). Le QR seul
        // laissait le colis inconfirmable : l'expéditeur peut en générer un
        // nouveau ici.
        'HANDED_OVER' || 'IN_TRANSIT' || 'ARRIVED' => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QrTalonButton(bid: bid, compact: true),
            const SizedBox(height: DonySpacing.sm),
            TalonBlockedCodeBlock(
              bidId: bid.id,
              expired: bid.isPickupCodeExpired,
            ),
          ],
        ),
        'COMPLETED' || 'DELIVERED' => const _DoneBlock(),
        'CANCELLED' => _CancelledBlock(bid: bid, isSender: true),
        'REJECTED' => _RejectedBlock(bid: bid, isSender: true),
        'EXPIRED' when bid.isExpiredAtHandoverDeadline =>
          const _HandoverDeadlineExpiredBlock(isSender: true),
        _ => const SizedBox.shrink(),
      };
    }

    // ── Traveler dispatch ───────────────────────────────────────────────────────
    return switch (status) {
      'PENDING' || 'PAYMENT_ESCROWED' => _TravelerDecisionSummary(bid: bid),
      // Voyageur vient d'accepter une offre mobile money : l'expéditeur a
      // 30 min pour séquestrer via pawaPay. Rien à faire ici tant que le
      // paiement n'est pas séquestré (le bid repasse alors en ACCEPTED) —
      // simple repère visuel, jamais d'action de scan.
      'AWAITING_PAYMENT' => const _TravelerAwaitingPaymentBlock(),
      // ACCEPTED / HANDED_OVER / IN_TRANSIT : accès au scan depuis le détail →
      // lien vers les étapes du Suivi (ScanHub : Départ/Transit/Arrivée + scan
      // QR + identification par numéro). La barre collante garde son CTA
      // contextuel (Scanner le colis / Valider la remise).
      // ARRIVED : le trajet est arrivé mais le scan d'arrivée reste à faire →
      // le voyageur garde l'accès aux étapes de scan.
      // Code de retrait bloqué ou expiré (FLUTTER-G2) : seul l'expéditeur
      // peut en générer un nouveau, le voyageur le lui demande d'ici. Sur un
      // back antérieur, le drapeau reste faux et le talon ne change pas.
      'HANDED_OVER' ||
      'IN_TRANSIT' ||
      'ARRIVED' when bid.pickupCodeRenewalNeeded => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TravelerScanStepsButton(bid: bid),
          const SizedBox(height: DonySpacing.sm),
          TalonCodeRenewalRequestBlock(bidId: bid.id),
        ],
      ),
      'ACCEPTED' ||
      'HANDED_OVER' ||
      'IN_TRANSIT' ||
      'ARRIVED' => _TravelerScanStepsButton(bid: bid),
      'COMPLETED' || 'DELIVERED' => const _DoneBlock(),
      'CANCELLED' => _CancelledBlock(bid: bid, isSender: false),
      'REJECTED' => _RejectedBlock(bid: bid, isSender: false),
      'EXPIRED' when bid.isExpiredAtHandoverDeadline =>
        const _HandoverDeadlineExpiredBlock(isSender: false),
      // Statuts terminaux sans bloc dédié : sans cela la zone du talon restait
      // vide et rien n'expliquait pourquoi la demande ne bouge plus.
      'NO_SHOW' ||
      'PARCEL_REFUSED' ||
      'EXPIRED' => _TravelerClosedBlock(status: status),
      _ => const SizedBox.shrink(),
    };
  }
}

/// any / CANCELLED — selon l'état de la restitution (annulation après remise, D7) :
/// - colis restitué → bloc « Colis restitué » ;
/// - retour en attente → action code de retour (afficher côté expéditeur, saisir
///   côté voyageur) ;
/// - sinon (annulation pré-remise classique) → message terminal neutre.
class _CancelledBlock extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const _CancelledBlock({required this.bid, required this.isSender});

  /// Trajets proposés à l'expéditeur (jamais au voyageur) : annulation du
  /// trajet ou du transport, et depuis la décision du propriétaire, colis
  /// annulé après remise (pendant et après son retour).
  bool get _showRematch =>
      isSender &&
      bid.tripCancellationId != null &&
      bid.tripCancellationRematchStatus == 'SUGGESTED';

  @override
  Widget build(BuildContext context) {
    // Annulation décidée par l'équipe (FLUTTER-R4) : motif et contact du
    // support en tête. Le retour du colis ou les trajets alternatifs, s'il y
    // en a, restent proposés dessous. Un ancien back laisse le marqueur nul.
    final team = TeamCancellationReason.fromCode(bid.rejectionReason);
    if (team == null) return _buildDefault(context);
    final teamBlock = _TeamCancelledBlock(
      bid: bid,
      isSender: isSender,
      reason: team,
    );
    final hasFollowUp =
        bid.isParcelReturned || bid.isAwaitingReturn || _showRematch;
    if (!hasFollowUp) return teamBlock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        teamBlock,
        const SizedBox(height: DonySpacing.sm),
        _buildDefault(context),
      ],
    );
  }

  Widget _buildDefault(BuildContext context) {
    if (bid.isParcelReturned) {
      if (!_showRematch) return const _ReturnedBlock();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ReturnedBlock(),
          _RematchCta(
            tripCancellationId: bid.tripCancellationId!,
            parcelReturn: true,
          ),
        ],
      );
    }
    final l = context.l10n;
    if (!bid.isAwaitingReturn) {
      // Annulation classique (pré-remise) : cas terminal simple. Le voyageur a
      // annulé son trajet (jamais no-show, cf. BidResponse.tripCancellationId
      // côté backend) et des trajets alternatifs sont disponibles → propose le
      // rematch à l'expéditeur.
      if (_showRematch) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TerminalBlock(),
            const SizedBox(height: DonySpacing.sm),
            _RematchCta(tripCancellationId: bid.tripCancellationId!),
          ],
        );
      }
      if (bid.rejectionReason == kCancelledBeforePaymentReason) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CancelledBeforePaymentLine(isSender: isSender),
            const _TerminalBlock(),
          ],
        );
      }
      return const _TerminalBlock();
    }
    final cs = Theme.of(context).colorScheme;
    final returnButton = OutlinedButton.icon(
      onPressed: () => isSender
          ? ReturnCodeSheet.show(context, bid: bid)
          : ReturnEntrySheet.show(context, bid: bid),
      icon: DonyIcon(
        isSender ? 'key-round' : 'clipboard-check',
        size: 20,
        color: cs.primary,
      ),
      label: Text(
        isSender ? l.ticketReturnCodeButton : l.ticketConfirmReturnButton,
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
    if (!_showRematch) return returnButton;
    // Retour en attente : le code d'abord, puis les trajets pour renvoyer le
    // colis une fois récupéré.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        returnButton,
        const SizedBox(height: DonySpacing.sm),
        _RematchCta(
          tripCancellationId: bid.tripCancellationId!,
          parcelReturn: true,
        ),
      ],
    );
  }
}

/// sender / REJECTED — message terminal ; si le bid a été refusé suite à
/// l'annulation du transport par le voyageur (annonce non annulée,
/// `bid.tripCancellationId` renseigné côté back) et que le rematch est
/// encore disponible, propose les trajets alternatifs à l'expéditeur, comme
/// pour [_CancelledBlock]. Côté voyageur, jamais de CTA.
class _RejectedBlock extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const _RejectedBlock({required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final showRematch =
        isSender &&
        bid.tripCancellationId != null &&
        bid.tripCancellationRematchStatus == 'SUGGESTED';
    // Motif choisi par le voyageur (FLUTTER-AF), absent pour un refus
    // automatique ou d'une ancienne version de l'app.
    final reason = BidRejectionReason.fromCode(bid.rejectionReason);
    if (!showRematch && reason == null) return const _TerminalBlock();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reason != null) _RejectionReasonLine(reason: reason),
        const _TerminalBlock(),
        if (showRematch) ...[
          const SizedBox(height: DonySpacing.sm),
          _RematchCta(tripCancellationId: bid.tripCancellationId!),
        ],
      ],
    );
  }
}

/// Motif posé par yadony-back sur une demande annulée par l'expéditeur
/// avant paiement (`POST /bids/{id}/cancel-before-payment`).
const kCancelledBeforePaymentReason = 'SENDER_CANCELLED_BEFORE_PAYMENT';

/// « Vous avez annulé… » / « L'expéditeur a annulé… avant le paiement ».
class _CancelledBeforePaymentLine extends StatelessWidget {
  final bool isSender;

  const _CancelledBeforePaymentLine({required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.sm),
      child: Text(
        isSender
            ? l.billetCancelledBeforePaymentSender
            : l.billetCancelledBeforePaymentTraveler,
        key: const Key('billet-cancelled-before-payment'),
        textAlign: TextAlign.center,
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// any / CANCELLED par l'équipe Yadony (FLUTTER-R4, yadony-back #567) :
/// « Annulé par l'équipe Yadony », le motif public s'il y en a un, puis
/// « Contacter le support », qui ouvre une demande préremplie sur ce colis.
///
/// Le remboursement n'est jamais affirmé : l'app ne sait pas si le paiement a
/// eu lieu (carte pas encore payée, par exemple). La ligne reste au
/// conditionnel, et disparaît pour un colis payé en espèces, hors de l'app.
class _TeamCancelledBlock extends StatelessWidget {
  final BidModel bid;
  final bool isSender;
  final TeamCancellationReason reason;

  const _TeamCancelledBlock({
    required this.bid,
    required this.isSender,
    required this.reason,
  });

  String _detail(AppLocalizations l) {
    final paidInApp = bid.paymentMethod != BidPaymentMethod.cash;
    if (!isSender) {
      return switch (reason) {
        TeamCancellationReason.travelerUnavailable =>
          l.billetTeamCancelledTravelerUnavailableTraveler,
        TeamCancellationReason.cancelled => l.billetTeamCancelledContactHint,
      };
    }
    return switch (reason) {
      TeamCancellationReason.travelerUnavailable when paidInApp =>
        '${l.billetTeamCancelledTravelerUnavailableSender} '
            '${l.billetTeamCancelledRefundSender}',
      TeamCancellationReason.travelerUnavailable =>
        l.billetTeamCancelledTravelerUnavailableSender,
      TeamCancellationReason.cancelled when paidInApp =>
        l.billetTeamCancelledRefundSender,
      TeamCancellationReason.cancelled => l.billetTeamCancelledContactHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(
      key: const Key('billet-team-cancelled'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: DonySpacing.sm),
        DonyIcon('shield', size: 22, color: cs.onSurfaceVariant),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.billetTeamCancelledTitle,
          textAlign: TextAlign.center,
          style: tt.titleSmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          _detail(l),
          key: const Key('billet-team-cancelled-detail'),
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.md),
        _TeamSupportCta(bid: bid, isSender: isSender),
      ],
    );
  }
}

/// « Contacter le support » : ouvre `/support` avec une demande préremplie
/// (catégorie Colis, sujet portant le numéro du colis, message d'amorce).
/// L'utilisateur relit et modifie avant d'envoyer : aucun ticket n'est créé
/// sans qu'il touche « Envoyer ».
class _TeamSupportCta extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const _TeamSupportCta({required this.bid, required this.isSender});

  /// Numéro de suivi, sinon le début de l'identifiant (lisible par l'équipe).
  /// Le voyageur ne voit le numéro qu'à partir de la remise
  /// ([travelerVisibleTrackingNumber]) : sur un colis annulé, il n'y a droit
  /// qu'à l'identifiant.
  String get _parcelNumber {
    final tracking =
        (isSender ? bid.trackingNumber : travelerVisibleTrackingNumber(bid))
            ?.trim();
    if (tracking != null && tracking.isNotEmpty) return tracking;
    final id = bid.id;
    return (id.length > 8 ? id.substring(0, 8) : id).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return OutlinedButton.icon(
      key: const Key('billet-team-support-cta'),
      onPressed: () => context.push(
        '/support',
        extra: SupportTicketDraft(
          category: 'PACKAGE',
          subject: l.billetTeamCancelledSupportSubject(_parcelNumber),
          message: l.billetTeamCancelledSupportMessage,
          origin: 'team_cancelled_parcel',
        ),
      ),
      icon: DonyIcon('headset', size: 20, color: cs.primary),
      label: Text(l.supportContactCta, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// « Motif du voyageur : … » au-dessus du message terminal d'un refus.
class _RejectionReasonLine extends StatelessWidget {
  final BidRejectionReason reason;

  const _RejectionReasonLine({required this.reason});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.sm),
      child: Text(
        l.bidRejectionReasonShown(bidRejectionReasonLabel(l, reason)),
        key: const Key('billet-rejection-reason'),
        textAlign: TextAlign.center,
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Bouton partagé « Voir les trajets alternatifs » — CTA rematch proposé à
/// l'expéditeur quand le voyageur a annulé son transport (bid CANCELLED ou
/// REJECTED, `tripCancellationRematchStatus == 'SUGGESTED'`). Ouvre l'écran
/// de recherche d'alternatives pour la [tripCancellationId] concernée.
/// Utilisé par [_CancelledBlock] et [_RejectedBlock].
class _RematchCta extends StatelessWidget {
  final String tripCancellationId;

  /// Colis remis puis annulé : l'écran l'annonce « à récupérer ».
  final bool parcelReturn;

  const _RematchCta({
    required this.tripCancellationId,
    this.parcelReturn = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      key: const Key('billet-rematch-cta'),
      onPressed: () => context.push(
        parcelReturn
            ? '/cancellations/$tripCancellationId/rematch?retour=1'
            : '/cancellations/$tripCancellationId/rematch',
      ),
      icon: DonyIcon('route', size: 20, color: cs.primary),
      label: Text(
        context.l10n.ticketViewAlternativeTripsButton,
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// any / CANCELLED + colis restitué — check vert + « Colis restitué ».
class _ReturnedBlock extends StatelessWidget {
  const _ReturnedBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        DonyIcon('circle-check', size: 40, color: cs.success),
        const SizedBox(height: DonySpacing.sm),
        Text(
          context.l10n.ticketParcelReturnedLabel,
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: cs.success,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

// ── Inline helper widgets ─────────────────────────────────────────────────────

/// sender / ACCEPTED · HANDED_OVER · IN_TRANSIT — bouton d'ouverture de la
/// [QrSheet] (QR du colis à présenter ou à coller).
///
/// En mode [compact] (côté IN_TRANSIT, à côté du code retrait), le label est
/// raccourci pour tenir dans une largeur contrainte ([Expanded]).
class _QrTalonButton extends StatelessWidget {
  final BidModel bid;
  final bool compact;

  const _QrTalonButton({required this.bid, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => QrSheet.show(context, bidId: bid.id, status: bid.status),
      icon: DonyIcon('qr-code', size: 20, color: cs.primary),
      label: Text(
        compact
            ? context.l10n.ticketQrButtonCompact
            : context.l10n.ticketQrButtonFull,
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// Bouton talon « Code de retrait » — ouvre la [RetraitCodeSheet].
///
/// Même comportement que [_QrTalonButton] : un bottom sheet porte le contenu
/// (digits, copier, régénérer, explication).
class _RetraitTalonButton extends StatelessWidget {
  final BidModel bid;

  const _RetraitTalonButton({required this.bid});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => RetraitCodeSheet.show(context, bid: bid),
      icon: DonyIcon('key-round', size: 20, color: cs.primary),
      label: Text(context.l10n.ticketPickupCode, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// traveler / HANDED_OVER · IN_TRANSIT — mode « Valider une étape » sur le
/// trajet de ce colis, où le voyageur scanne (QR) ou saisit le numéro.
/// Poussé, pas `go` : le retour ramène au colis (FLUTTER-9N).
class _TravelerScanStepsButton extends StatelessWidget {
  const _TravelerScanStepsButton({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () => openTripValidation(context, bid),
      icon: DonyIcon('scan-line', size: 20, color: cs.primary),
      label: Text(
        context.l10n.ticketScanStepsButton,
        textAlign: TextAlign.center,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.primary),
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
        ),
      ),
    );
  }
}

/// sender / PENDING — Hourglass + "En attente de confirmation du voyageur",
/// ou "En attente de votre paiement" pour un colis carte pas encore payé.
class _PendingPlaceholder extends StatelessWidget {
  const _PendingPlaceholder({this.awaitingMyPayment = false});

  final bool awaitingMyPayment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        DonyIcon('hourglass', size: 32, color: cs.onSurfaceVariant),
        const SizedBox(height: DonySpacing.sm),
        Text(
          awaitingMyPayment
              ? context.l10n.ticketAwaitingSenderCardPayment
              : context.l10n.ticketAwaitingTravelerConfirmation,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

/// traveler / AWAITING_PAYMENT — Hourglass + « En attente du paiement de
/// l'expéditeur ». L'expéditeur a jusqu'à 30 min pour séquestrer son
/// paiement mobile money : rien à faire côté voyageur ici, juste un repère
/// visuel le temps que le statut évolue (ACCEPTED au séquestre, annulation
/// automatique sinon).
/// Côté expéditeur, offre mobile money acceptée : le voyageur a confirmé, il
/// reste à payer depuis la barre collante du détail (30 min).
class _SenderAwaitingPaymentBlock extends StatelessWidget {
  const _SenderAwaitingPaymentBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        DonyIcon('smartphone', size: 32, color: cs.primary),
        const SizedBox(height: DonySpacing.sm),
        Text(
          context.l10n.ticketSenderAwaitingMobileMoneyHint,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

class _TravelerAwaitingPaymentBlock extends StatelessWidget {
  const _TravelerAwaitingPaymentBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        DonyIcon('hourglass', size: 32, color: cs.onSurfaceVariant),
        const SizedBox(height: DonySpacing.sm),
        Text(
          context.l10n.ticketTravelerAwaitingPayment,
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

/// any / COMPLETED or DELIVERED — green check + "Colis livré".
class _DoneBlock extends StatelessWidget {
  const _DoneBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        DonyIcon('circle-check', size: 40, color: cs.success),
        const SizedBox(height: DonySpacing.sm),
        Text(
          context.l10n.ticketParcelDeliveredLabel,
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: cs.success,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

/// any / REJECTED or CANCELLED (et NO_SHOW / PARCEL_REFUSED / EXPIRED côté
/// voyageur, sous leur motif) — muted terminal message.
class _TerminalBlock extends StatelessWidget {
  const _TerminalBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      child: Text(
        context.l10n.ticketRequestClosedMessage,
        textAlign: TextAlign.center,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// traveler / NO_SHOW, PARCEL_REFUSED, EXPIRED (hors date limite de dépôt) :
/// le motif, avec le vocabulaire du tampon, puis le message terminal commun.
/// Côté expéditeur la zone du talon reste vide pour ces statuts.
class _TravelerClosedBlock extends StatelessWidget {
  final String status;

  const _TravelerClosedBlock({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final reason = switch (status) {
      'NO_SHOW' => l.ticketClosedNoShowReason,
      'PARCEL_REFUSED' => l.ticketClosedParcelRefusedReason,
      _ => l.ticketClosedExpiredReason,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: DonySpacing.sm),
          child: Text(
            reason,
            key: const Key('billet-closed-reason'),
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const _TerminalBlock(),
      ],
    );
  }
}

/// any / EXPIRED à la date limite de dépôt (FLUTTER-GA) : la demande, jamais
/// acceptée, a été annulée automatiquement par le serveur. L'expéditeur lit
/// qu'il est remboursé intégralement (Yadony ne retient jamais rien).
class _HandoverDeadlineExpiredBlock extends StatelessWidget {
  final bool isSender;

  const _HandoverDeadlineExpiredBlock({required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      key: const Key('billet-handover-deadline-expired'),
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      child: Column(
        children: [
          DonyIcon('calendar-x', size: 22, color: cs.onSurfaceVariant),
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.ticketHandoverDeadlineExpiredTitle,
            textAlign: TextAlign.center,
            style: tt.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            isSender
                ? l.ticketHandoverDeadlineExpiredSender
                : l.ticketHandoverDeadlineExpiredTraveler,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// traveler / PENDING — 3 mini-stats : poids, valeur, catégorie.
class _TravelerDecisionSummary extends StatelessWidget {
  final BidModel bid;
  const _TravelerDecisionSummary({required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    final weight = bid.displayWeightKg != null
        ? '${bid.displayWeightKg!.toStringAsFixed(1)} kg'
        : '-';
    final category = bid.contentCategory != null
        ? contentCategoriesDisplayName(l, bid.contentCategory!)
        : '-';

    return Row(
      children: [
        _MiniStat(value: weight, label: l.ticketMiniStatWeightLabel, tt: tt),
        _MiniStat(
          value: category,
          label: l.ticketMiniStatCategoryLabel,
          tt: tt,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final TextTheme tt;

  const _MiniStat({required this.value, required this.label, required this.tt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FittedBox scaleDown : une catégorie longue (« Médicaments »,
          // « Électronique ») rétrécit au lieu de s'ellipser en « Médi… » ;
          // une valeur courte garde sa taille. Une seule ligne pour ne pas
          // désaligner les 3 colonnes du talon.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            // bodySmall = 12px — plancher HIG ≥ 12px
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
