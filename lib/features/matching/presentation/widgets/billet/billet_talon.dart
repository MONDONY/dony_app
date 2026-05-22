import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_retrait_code_view.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:dony/features/tracking/presentation/widgets/qr_code_card.dart';
import 'package:flutter/material.dart';

/// Zone action + bande de suivi du talon bas du billet de colis.
///
/// Dispatcher : selon [bid.status] × [isSender], affiche le bon contenu
/// d'action (QR, code retrait, scan, confirmation, placeholder, done…).
/// Si [bid.trackingNumber] est non-null, la [TalonTrackingStrip] est
/// toujours ajoutée en bas, quelle que soit l'action.
///
/// NOTE : les cases [QrCodeCard] et [TalonRetraitCodeView] consomment des
/// BLoCs ambiants (TrackingBloc / BidBloc) fournis par l'écran parent.
/// Ce widget n'injecte aucun [BlocProvider].
class BilletTalon extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const BilletTalon({super.key, required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
          if (bid.trackingNumber != null) ...[
            const SizedBox(height: DonySpacing.md),
            TalonTrackingStrip(trackingNumber: bid.trackingNumber!),
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
        'PENDING' => const _PendingPlaceholder(),
        'ACCEPTED' => QrCodeCard(bidId: bid.id),
        'HANDED_OVER' ||
        'IN_TRANSIT' when bid.confirmationCode != null => TalonRetraitCodeView(
          bidId: bid.id,
          initialCode: bid.confirmationCode!,
          refreshCount: bid.confirmationCodeRefreshCount,
          refreshWindowStart: bid.confirmationCodeRefreshWindowStart,
        ),
        'HANDED_OVER' || 'IN_TRANSIT' =>
          // confirmationCode is null — render a neutral waiting indicator
          const _InTransitWaitingPlaceholder(),
        'COMPLETED' || 'DELIVERED' => const _DoneBlock(),
        'REJECTED' || 'CANCELLED' => const _TerminalBlock(),
        _ => const SizedBox.shrink(),
      };
    }

    // ── Traveler dispatch ─────────────────────────────────────────────────────
    return switch (status) {
      'PENDING' => _TravelerDecisionSummary(bid: bid),
      'ACCEPTED' => TalonTravelerActionView(
        bidId: bid.id,
        action: TalonTravelerAction.scan,
        travelerName: bid.travelerName,
      ),
      'HANDED_OVER' || 'IN_TRANSIT' => TalonTravelerActionView(
        bidId: bid.id,
        action: TalonTravelerAction.confirmDelivery,
        travelerName: bid.travelerName,
      ),
      'COMPLETED' || 'DELIVERED' => const _DoneBlock(),
      'REJECTED' || 'CANCELLED' => const _TerminalBlock(),
      _ => const SizedBox.shrink(),
    };
  }
}

// ── Inline helper widgets ─────────────────────────────────────────────────────

/// sender / PENDING — Hourglass + "En attente de confirmation du voyageur".
class _PendingPlaceholder extends StatelessWidget {
  const _PendingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        Icon(Icons.hourglass_top_rounded, size: 32, color: cs.onSurfaceVariant),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'En attente de confirmation du voyageur',
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.sm),
      ],
    );
  }
}

/// sender / HANDED_OVER or IN_TRANSIT without confirmationCode.
class _InTransitWaitingPlaceholder extends StatelessWidget {
  const _InTransitWaitingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: DonySpacing.sm),
        Icon(Icons.local_shipping_rounded, size: 32, color: cs.primary),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Colis en route',
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
        Icon(Icons.check_circle_rounded, size: 40, color: cs.success),
        const SizedBox(height: DonySpacing.sm),
        Text(
          'Colis livré',
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

/// any / REJECTED or CANCELLED — muted terminal message.
class _TerminalBlock extends StatelessWidget {
  const _TerminalBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      child: Text(
        'Cette demande est terminée.',
        textAlign: TextAlign.center,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

    final weight = bid.weightKg != null ? '${bid.weightKg!.toStringAsFixed(1)} kg' : '—';
    final value = bid.declaredValueEur != null
        ? '${bid.declaredValueEur!.toStringAsFixed(0)} €'
        : '—';
    final category = bid.contentCategory ?? '—';

    return Row(
      children: [
        _MiniStat(value: weight, label: 'POIDS', tt: tt),
        _MiniStat(value: value, label: 'VALEUR', tt: tt),
        _MiniStat(value: category, label: 'TYPE', tt: tt),
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
          Text(
            value,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
