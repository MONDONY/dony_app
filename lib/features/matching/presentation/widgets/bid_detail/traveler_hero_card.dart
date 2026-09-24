import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TravelerHeroVariant { wait, info, done, alert }

// ── Public widget ─────────────────────────────────────────────────────────────

/// Carte "prochaine étape" contextuelle au statut du bid (vue voyageur).
///
/// Affiche l'action suivante selon le statut : nouvelle demande, récupération
/// du colis, scan QR, transit, livraison confirmée.
/// Gère aussi la fenêtre de remise dépassée (signalement absence expéditeur).
class TravelerHeroCard extends StatelessWidget {
  const TravelerHeroCard({super.key, required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    // ── Priorité 1 : absence déjà signalée (en attente / contestée) ───────
    // Le bid reste 'ACCEPTED' tant que l'expéditeur n'a pas confirmé/contesté
    // et que le délai n'est pas expiré. Sans ce check, on ré-afficherait
    // « Signaler l'absence » alors que le signalement est déjà fait.
    final noShowStatus = bid.cancellationNoShowStatus;
    if (noShowStatus == 'PENDING_CONFIRMATION' || noShowStatus == 'CONTESTED') {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _NoShowReportedHero(
          contested: noShowStatus == 'CONTESTED',
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
    if (deliveryStatus == 'PENDING_CONFIRMATION' ||
        deliveryStatus == 'CONTESTED') {
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
    final deadline = bid.handoverDeadline;
    if (bid.status == 'ACCEPTED' &&
        deadline != null &&
        DateTime.now().isAfter(deadline)) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _WindowExpiredHero(
          bid: bid,
          key: ValueKey('TRAVELER_WINDOW_EXPIRED${bid.id}'),
        ),
      );
    }

    // ── Priorité 2 : mapping par statut ────────────────────────────────────
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

_HeroContent? _buildContent(BuildContext context, BidModel bid) {
  final l = context.l10n;
  switch (bid.status) {
    case 'PENDING':
      final amount = travelerAmountLabel(bid);
      return _HeroContent(
        variant: TravelerHeroVariant.wait,
        title: l.bidDetailTravelerPendingTitle,
        subtitle: l.bidDetailTravelerPendingSubtitle(amount),
      );

    case 'ACCEPTED':
      if (bid.voyageurConfirmed) {
        return _HeroContent(
          variant: TravelerHeroVariant.info,
          title: l.bidDetailTravelerScanQrTitle,
          subtitle: l.bidDetailTravelerScanQrSubtitle,
        );
      }
      final subtitle = _buildAcceptedSubtitle(context, bid);
      return _HeroContent(
        variant: TravelerHeroVariant.info,
        title: l.bidDetailTravelerAcceptedTitle,
        subtitle: subtitle,
      );

    case 'HANDED_OVER':
      return _HeroContent(
        variant: TravelerHeroVariant.info,
        title: l.bidDetailTravelerCollectedTitle,
        subtitle: l.bidDetailTravelerCollectedSubtitle,
      );

    case 'IN_TRANSIT':
      final arrivalCity = bid.arrivalCity ?? l.bidDetailFallbackDestination;
      return _HeroContent(
        variant: TravelerHeroVariant.info,
        title: l.bidDetailTravelerInTransitTitle,
        subtitle: l.bidDetailTravelerInTransitSubtitle(arrivalCity),
      );

    case 'ARRIVED':
      return _HeroContent(
        variant: TravelerHeroVariant.info,
        title: l.bidDetailTravelerArrivedTitle,
        subtitle: l.bidDetailTravelerArrivedSubtitle,
      );

    case 'COMPLETED':
    case 'DELIVERED':
      return _HeroContent(
        variant: TravelerHeroVariant.done,
        title: l.bidDetailTravelerDeliveredTitle,
        subtitle: l.bidDetailTravelerDeliveredSubtitle,
      );

    // Terminal or unknown statuses → shrink
    case 'REJECTED':
    case 'CANCELLED':
    case 'NO_SHOW':
    case 'EXPIRED':
    case 'PARCEL_REFUSED':
    default:
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
  try {
    return l.bidDetailUntil(DateFormat.MMMEd(locale).format(deadline));
  } catch (_) {
    // Repli quand les données de locale manquent (tests isolés).
    return l.bidDetailUntil(DateFormat.Md(locale).format(deadline));
  }
}

String _buildAcceptedSubtitle(BuildContext context, BidModel bid) {
  final l = context.l10n;
  final window = _formatDeadline(context, bid.handoverDeadline);
  final location = bid.handoverLocation;
  final parts = <String>[];
  if (window.isNotEmpty) {
    parts.add(window);
  }
  if (location != null && location.isNotEmpty) {
    parts.add(location);
  }
  final base = parts.join(' · ');
  if (base.isNotEmpty) {
    return '$base.\n${l.bidDetailTravelerAcceptedInstructions}';
  }
  return l.bidDetailTravelerAcceptedInstructionsDefault;
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

  List<Color> _gradientColors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (variant) {
      case TravelerHeroVariant.wait:
        return [DonyColors.ink600, DonyColors.ink800];
      case TravelerHeroVariant.info:
        return [DonyColors.blue500, DonyColors.blue700];
      case TravelerHeroVariant.done:
        return [DonyColors.blue600, DonyColors.blue800];
      case TravelerHeroVariant.alert:
        return [cs.error, DonyColors.ink800];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final colors = _gradientColors(context);
    const white = Color(0xFFFFFFFF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleLarge?.copyWith(
              color: white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
          Text(
            subtitle,
            style: tt.bodySmall?.copyWith(
              color: white.withValues(alpha: 0.85),
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
  const _NoShowReportedHero({super.key, required this.contested});

  final bool contested;

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
          : l.bidDetailTravelerNoShowPendingSubtitle,
    );
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
              : l.bidDetailDeliveryNoShowAlertSubtitle,
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
