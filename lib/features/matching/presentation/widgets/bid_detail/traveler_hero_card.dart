import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/bloc/cancellation_bloc.dart';
import 'package:dony/features/cancellation/bloc/cancellation_event.dart';
import 'package:dony/features/cancellation/bloc/cancellation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
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
  switch (bid.status) {
    case 'PENDING':
      final amount = travelerAmountLabel(bid);
      return _HeroContent(
        variant: TravelerHeroVariant.wait,
        title: '📨 Nouvelle demande d\'envoi',
        subtitle: 'Gain potentiel : $amount. Acceptez ou refusez la demande.',
      );

    case 'ACCEPTED':
      if (bid.voyageurConfirmed) {
        return const _HeroContent(
          variant: TravelerHeroVariant.info,
          title: '📷 Lisez le QR du colis',
          subtitle:
              'Lisez le QR code de l\'expéditeur pour confirmer la prise en charge.',
        );
      }
      final subtitle = _buildAcceptedSubtitle(bid);
      return _HeroContent(
        variant: TravelerHeroVariant.info,
        title: '⚡ Récupérez le colis',
        subtitle: subtitle,
      );

    case 'HANDED_OVER':
      return const _HeroContent(
        variant: TravelerHeroVariant.info,
        title: '✓ Colis récupéré',
        subtitle: 'Le colis est en votre possession. Bon voyage !',
      );

    case 'IN_TRANSIT':
      final arrivalCity = bid.arrivalCity ?? 'destination';
      return _HeroContent(
        variant: TravelerHeroVariant.info,
        title: '✈ Colis en route',
        subtitle: 'En transit vers $arrivalCity. Bonne livraison !',
      );

    case 'ARRIVED':
      return const _HeroContent(
        variant: TravelerHeroVariant.info,
        title: '📍 Arrivé à destination',
        subtitle:
            'Attendez que le destinataire récupère le colis, puis validez la remise.',
      );

    case 'COMPLETED':
    case 'DELIVERED':
      return const _HeroContent(
        variant: TravelerHeroVariant.done,
        title: '✓ Livraison confirmée',
        subtitle: 'Le paiement va être libéré sur votre compte.',
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

String _formatDeadline(DateTime? deadline) {
  if (deadline == null) {
    return '';
  }
  try {
    return 'jusqu\'au ${DateFormat('EEE d MMM', 'fr').format(deadline)}';
  } catch (_) {
    // Repli quand les données de locale manquent (tests isolés).
    return 'jusqu\'au ${DateFormat('dd/MM').format(deadline)}';
  }
}

String _buildAcceptedSubtitle(BidModel bid) {
  final window = _formatDeadline(bid.handoverDeadline);
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
    return '$base.\nPrésentez-vous au point de remise.';
  }
  return 'Présentez-vous au point de remise convenu avec l\'expéditeur.';
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
    final window = _formatDeadline(bid.handoverDeadline);
    final subtitle = window.isNotEmpty
        ? 'Le dépôt était possible $window. L\'expéditeur ne s\'est pas présenté ?'
        : "L'expéditeur ne s'est pas présenté au point de dépôt ?";

    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: TravelerHeroVariant.alert,
          title: '⚠ Date limite de dépôt dépassée',
          subtitle: subtitle,
          footer: _HeroButton(
            label: "Signaler l'absence de l'expéditeur",
            isLoading: isLoading,
            onPressed: () => _showNoShowSheet(context),
          ),
        );
      },
    );
  }

  Future<void> _showNoShowSheet(BuildContext context) async {
    final confirmed = await DonyBottomSheet.show<bool>(
      context,
      title: "L'expéditeur ne s'est pas présenté ?",
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          label: "Signaler l'absence",
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
              "L'expéditeur ne s'est pas présenté au point de remise.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: DonySpacing.md),
            Text(
              "L'expéditeur aura 48 h pour contester. "
              'Sans réponse de sa part, l\'envoi sera annulé.',
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
    return _HeroShell(
      variant: TravelerHeroVariant.wait,
      title: contested ? '⚖ Absence contestée' : '⏳ Absence signalée',
      subtitle: contested
          ? "L'expéditeur conteste votre signalement. Notre équipe examine la "
                'demande et vous tiendra informé.'
          : "Signalement envoyé. L'expéditeur a 48 h pour confirmer ou "
                'contester. Sans réponse, l\'envoi sera annulé automatiquement.',
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
    if (iAmReporter) {
      return _HeroShell(
        variant: TravelerHeroVariant.wait,
        title: contested ? '⚖ Absence contestée' : '⏳ Absence signalée',
        subtitle: contested
            ? "L'autre partie conteste votre signalement. Notre équipe examine "
                  'la demande et vous tiendra informé.'
            : "Signalement envoyé. L'autre partie a 24 h pour contester. "
                  'Notre équipe tranche ensuite.',
      );
    }
    return BlocBuilder<CancellationBloc, CancellationState>(
      builder: (context, state) {
        final isLoading = state is CancellationLoading;
        return _HeroShell(
          variant: TravelerHeroVariant.alert,
          title: contested
              ? '⚖ Contestation envoyée'
              : '⚠ Une absence est signalée',
          subtitle: contested
              ? 'Votre contestation a été transmise. Notre équipe examine '
                    'la demande et vous tiendra informé.'
              : 'Une absence à la livraison a été signalée sur cet envoi. '
                    'Vous pouvez contester si ce signalement est erroné.',
          footer: contested
              ? null
              : _HeroButton(
                  label: 'Contester ce signalement',
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
