import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TravelerHeroVariant { wait, alert }

// ── Public widget ─────────────────────────────────────────────────────────────

/// Carte d'en-tête de la fiche colis (vue voyageur) : la demande à décider,
/// l'attente du paiement de l'expéditeur, et les alertes liées à une absence
/// (absence de l'expéditeur signalée ou contestée, absence à la livraison,
/// date limite de dépôt dépassée avec « Signaler l'absence de l'expéditeur »).
///
/// Les étapes du transport (ACCEPTED, HANDED_OVER, IN_TRANSIT, ARRIVED,
/// COMPLETED) n'ont plus de carte d'information : le footer (« Confirmer ma
/// présence », « Lire le QR du colis », « Valider la remise ») et le tampon du
/// billet disent déjà où en est le colis (décision du propriétaire).
class TravelerHeroCard extends StatelessWidget {
  const TravelerHeroCard({super.key, required this.bid});

  final BidModel bid;

  /// Priorité 1 : absence de l'expéditeur au dépôt déjà signalée (en attente
  /// de réponse ou contestée). Lue aussi par le footer, qui ne propose alors
  /// pas le scan après la date limite.
  static bool senderNoShowOpen(BidModel bid) =>
      bid.cancellationNoShowStatus == 'PENDING_CONFIRMATION' ||
      bid.cancellationNoShowStatus == 'CONTESTED';

  /// Priorité 1b : absence à la livraison déjà signalée.
  static bool _deliveryNoShowOpen(BidModel bid) =>
      bid.deliveryNoShowStatus == 'PENDING_CONFIRMATION' ||
      bid.deliveryNoShowStatus == 'CONTESTED';

  /// Priorité 2 : colis accepté dont la date limite de dépôt est dépassée.
  /// Lue aussi par le footer (« Confirmer ma présence » avant, plus après).
  static bool windowExpired(BidModel bid) {
    final deadline = bid.handoverDeadline;
    return bid.status == 'ACCEPTED' &&
        deadline != null &&
        DateTime.now().isAfter(deadline);
  }

  /// La carte rend quelque chose (sinon `SizedBox.shrink`) : un signalement en
  /// cours, la date limite dépassée ou un contenu de priorité 3
  /// ([_contentKind]).
  static bool isShown(BidModel bid) =>
      senderNoShowOpen(bid) ||
      _deliveryNoShowOpen(bid) ||
      windowExpired(bid) ||
      _contentKind(bid) != null;

  /// La carte porte un bouton (un `footer`) : elle va dans « À traiter » au
  /// lieu de rester sous le billet. Dans l'ordre des priorités de [build] :
  /// - 1, absence de l'expéditeur signalée ou contestée : variante `wait`, sans
  ///   bouton → `false` (et elle masque tout le reste) ;
  /// - 1b, absence à la livraison signalée par l'expéditeur CONTRE le voyageur,
  ///   pas encore contestée : « Contester ce signalement » → `true` ; une fois
  ///   contestée, alerte rouge sans bouton (« contestation envoyée ») →
  ///   `false` ; signalée par le voyageur lui-même : `wait`, sans bouton →
  ///   `false` ;
  /// - 2, date limite de dépôt dépassée (ACCEPTED) : « Signaler l'absence de
  ///   l'expéditeur » → `true` ;
  /// - 3, mapping par statut (demande à décider, attente du paiement) :
  ///   information seule, sans bouton → `false`.
  static bool hasAction(BidModel bid) {
    if (senderNoShowOpen(bid)) return false;
    if (_deliveryNoShowOpen(bid)) {
      return bid.deliveryNoShowReportedByTraveler != true &&
          bid.deliveryNoShowStatus != 'CONTESTED';
    }
    return windowExpired(bid);
  }

  @override
  Widget build(BuildContext context) {
    // ── Priorité 1 : absence déjà signalée (en attente / contestée) ───────
    // Le bid reste 'ACCEPTED' tant que l'expéditeur n'a pas confirmé/contesté
    // et que le délai n'est pas expiré. Sans ce check, on ré-afficherait
    // « Signaler l'absence » alors que le signalement est déjà fait.
    final noShowStatus = bid.cancellationNoShowStatus;
    if (senderNoShowOpen(bid)) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _NoShowReportedHero(
          contested: noShowStatus == 'CONTESTED',
          contestationDeadline: bid.contestationDeadline,
          key: ValueKey('TRAVELER_NOSHOW_$noShowStatus${bid.id}'),
        ),
      );
    }

    // ── Priorité 1b : absence à la livraison déjà signalée ────────────────
    // bid.deliveryNoShowReportedByTraveler distingue qui a signalé : le
    // voyageur (true, lui-même) ou l'expéditeur (false, l'adversaire) — sans
    // ce champ, deliveryNoShowStatus seul ne suffit pas à savoir qui doit
    // voir "Absence signalée" (auteur) vs "Une absence est signalée" (adversaire).
    final deliveryStatus = bid.deliveryNoShowStatus;
    if (_deliveryNoShowOpen(bid)) {
      final iAmReporter = bid.deliveryNoShowReportedByTraveler == true;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _DeliveryNoShowHero(
          bid: bid,
          iAmReporter: iAmReporter,
          contested: deliveryStatus == 'CONTESTED',
          key: ValueKey('TRAVELER_DELIVERY_NOSHOW_$deliveryStatus${bid.id}'),
        ),
      );
    }

    // ── Priorité 2 : date limite de dépôt dépassée ────────────────────────
    if (windowExpired(bid)) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _WindowExpiredHero(
          bid: bid,
          key: ValueKey('TRAVELER_WINDOW_EXPIRED${bid.id}'),
        ),
      );
    }

    // ── Priorité 3 : mapping par statut ────────────────────────────────────
    final content = _buildContent(context, bid);
    if (content == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _HeroShell(
        key: ValueKey('TRAVELER_${bid.status}${content.title}'),
        variant: content.variant,
        title: content.title,
        subtitle: content.subtitle,
      ),
    );
  }
}

// ── Internal data class ────────────────────────────────────────────────────────

class _HeroContent {
  const _HeroContent({
    required this.variant,
    required this.title,
    required this.subtitle,
  });

  final TravelerHeroVariant variant;
  final String title;
  final String subtitle;
}

// ── Status mapping ────────────────────────────────────────────────────────────

/// Contenu de priorité 3, par statut.
enum _ContentKind {
  /// Au voyageur de décider. PAYMENT_ESCROWED (carte déjà séquestrée) a aussi
  /// son hero : sans lui, « En attente » et deux boutons restaient sans
  /// contexte (FLUTTER-4T).
  request,

  /// Paiement de l'expéditeur attendu : rien à faire pour le voyageur.
  awaitingPayment,
}

/// Contenu de priorité 3 de [bid], `null` pour les étapes du transport, les
/// statuts clos et inconnus. Fonction pure : [TravelerHeroCard.isShown] et
/// [_buildContent] la lisent toutes deux.
_ContentKind? _contentKind(BidModel bid) => switch (bid.status) {
  'PENDING' || 'PAYMENT_ESCROWED' => _ContentKind.request,
  'AWAITING_PAYMENT' => _ContentKind.awaitingPayment,
  _ => null,
};

_HeroContent? _buildContent(BuildContext context, BidModel bid) {
  final l = context.l10n;
  switch (_contentKind(bid)) {
    case _ContentKind.request:
      final amount = travelerAmountLabel(bid);
      return _HeroContent(
        variant: TravelerHeroVariant.wait,
        title: l.bidDetailTravelerRequestTitle(bid.senderDisplayName(l)),
        subtitle: l.bidDetailTravelerPendingSubtitle(amount),
      );

    case _ContentKind.awaitingPayment:
      final mobileMoney = bid.paymentMethod == BidPaymentMethod.mobileMoney;
      return _HeroContent(
        variant: TravelerHeroVariant.wait,
        title: mobileMoney
            ? l.bidDetailTravelerAwaitingPaymentAcceptedTitle
            : l.bidDetailTravelerAwaitingPaymentTitle,
        subtitle: mobileMoney
            ? l.bidDetailTravelerAwaitingPaymentMobileMoneySubtitle
            : l.bidDetailTravelerAwaitingPaymentSubtitle,
      );

    case null:
      return null;
  }
}

// ── Date / window helpers ─────────────────────────────────────────────────────

String _formatDeadline(BuildContext context, DateTime? deadline) {
  if (deadline == null) {
    return '';
  }
  final l = context.l10n;
  final locale = l.localeName;
  // Instant UTC : jour de l'appareil, le colis ne porte pas le fuseau du
  // trajet (PROD-1R).
  final local = deadline.toLocal();
  try {
    return l.bidDetailUntil(DateFormat.MMMEd(locale).format(local));
  } catch (_) {
    // Repli quand les données de locale manquent (tests isolés).
    return l.bidDetailUntil(DateFormat.Md(locale).format(local));
  }
}

// ── _HeroShell ────────────────────────────────────────────────────────────────

class _HeroShell extends StatelessWidget {
  const _HeroShell({
    super.key,
    required this.variant,
    required this.title,
    required this.subtitle,
    this.footer,
  });

  final TravelerHeroVariant variant;
  final String title;
  final String subtitle;
  final Widget? footer;

  /// Aplat uni de la carte, sombre dans les deux thèmes, sous un texte blanc
  /// (≥ 4.5:1), comme les boutons `_HeroButton`.
  Color get _background => switch (variant) {
    TravelerHeroVariant.wait => DonyColors.ink700,
    TravelerHeroVariant.alert => DonyColors.danger700,
  };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final background = _background;
    const foreground = Color(0xFFFFFFFF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            subtitle,
            style: tt.bodySmall?.copyWith(
              color: foreground.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: DonySpacing.base),
            footer!,
          ],
        ],
      ),
    );
  }
}

// ── _HeroButton (OutlinedButton custom, NOT a DonyButton) ─────────────────────

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);

    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          backgroundColor: white.withValues(alpha: 0.14),
          side: BorderSide(color: white.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.md),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: white),
              )
            : FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
      ),
    );
  }
}

// ── Hero : date limite de dépôt dépassée ──────────────────────────────────────

class _WindowExpiredHero extends StatelessWidget {
  const _WindowExpiredHero({super.key, required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final window = _formatDeadline(context, bid.handoverDeadline);
    final subtitle = window.isNotEmpty
        ? l.bidDetailTravelerWindowExpiredSubtitleWithWindow(window)
        : l.bidDetailTravelerWindowExpiredSubtitleDefault;

    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: TravelerHeroVariant.alert,
          title: l.bidDetailTravelerWindowExpiredTitle,
          subtitle: subtitle,
          footer: _HeroButton(
            label: l.bidDetailTravelerReportNoShowButton,
            isLoading: isLoading,
            onPressed: () => _showNoShowSheet(context),
          ),
        );
      },
    );
  }

  Future<void> _showNoShowSheet(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: l.bidDetailTravelerNoShowSheetTitle,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: l.bidDetailReportNoShowConfirmButton,
          iconAsset: 'user-x',
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(true),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.bidDetailTravelerNoShowSheetBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              l.bidDetailTravelerNoShowSheetHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    context.read<CancellationBloc>().add(NoShowReportRequested(bid.id));
  }
}

// ── Hero : absence déjà signalée (en attente / contestée) ─────────────────────

class _NoShowReportedHero extends StatelessWidget {
  const _NoShowReportedHero({
    super.key,
    required this.contested,
    this.contestationDeadline,
  });

  final bool contested;

  /// Échéance renvoyée par le serveur (délai de contestation réel, 24 h par
  /// défaut côté back). Quand elle manque, le sous-titre retombe sur la
  /// durée fixe.
  final DateTime? contestationDeadline;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _HeroShell(
      variant: TravelerHeroVariant.wait,
      title: contested
          ? l.bidDetailNoShowContestedTitle
          : l.bidDetailNoShowReportedTitle,
      subtitle: contested
          ? l.bidDetailTravelerNoShowContestedSubtitle
          : _pendingSubtitle(context),
    );
  }

  String _pendingSubtitle(BuildContext context) {
    final l = context.l10n;
    final deadline = contestationDeadline?.toLocal();
    if (deadline == null) {
      return l.bidDetailTravelerNoShowPendingSubtitle;
    }
    final locale = l.localeName;
    try {
      return l.bidDetailTravelerNoShowPendingSubtitleUntil(
        DateFormat.MMMEd(locale).format(deadline),
        DateFormat.jm(locale).format(deadline),
      );
    } catch (_) {
      // Repli sur la durée fixe quand les données de locale manquent.
      return l.bidDetailTravelerNoShowPendingSubtitle;
    }
  }
}

// ── Hero : absence à la livraison signalée ────────────────────────────────────

class _DeliveryNoShowHero extends StatelessWidget {
  const _DeliveryNoShowHero({
    super.key,
    required this.bid,
    required this.iAmReporter,
    required this.contested,
  });

  final BidModel bid;
  final bool iAmReporter;
  final bool contested;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (iAmReporter) {
      return _HeroShell(
        variant: TravelerHeroVariant.wait,
        title: contested
            ? l.bidDetailNoShowContestedTitle
            : l.bidDetailNoShowReportedTitle,
        subtitle: contested
            ? l.bidDetailDeliveryNoShowReporterContestedSubtitle
            : l.bidDetailDeliveryNoShowReporterPendingSubtitle,
      );
    }
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: TravelerHeroVariant.alert,
          title: contested
              ? l.bidDetailDeliveryNoShowContestSentTitle
              : l.bidDetailDeliveryNoShowAlertTitle,
          subtitle: contested
              ? l.bidDetailDeliveryNoShowContestSentSubtitle
              : deliveryNoShowAlertSubtitle(l, bid),
          footer: contested
              ? null
              : _HeroButton(
                  label: l.bidDetailDeliveryNoShowContestButton,
                  isLoading: isLoading,
                  onPressed: () => context.read<CancellationBloc>().add(
                    DeliveryNoShowContestRequested(bid.id),
                  ),
                ),
        );
      },
    );
  }
}
