import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_retrait_code_view.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_tracking_strip.dart';
import 'package:dony/features/matching/presentation/widgets/billet/talon_traveler_action_view.dart';
import 'package:flutter/material.dart';

/// Zone action + bande de suivi du talon bas du billet de colis.
///
/// Dispatcher : selon [bid.status] × [isSender], affiche le bon contenu
/// d'action (QR, code retrait, scan, confirmation, placeholder, done…).
/// Si [bid.trackingNumber] est non-null, la [TalonTrackingStrip] est
/// toujours ajoutée en bas, quelle que soit l'action.
///
/// NOTE : les cases [_QrTalonButton] (ouvre la [QrSheet]) et
/// [TalonRetraitCodeView] consomment des BLoCs ambiants (TrackingBloc /
/// BidBloc) fournis par l'écran parent. Ce widget n'injecte aucun
/// [BlocProvider].
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
        'PENDING' ||
        'AWAITING_PAYMENT' ||
        'PAYMENT_ESCROWED' => const _PendingPlaceholder(),
        'ACCEPTED' => _QrTalonButton(bid: bid),
        // Le code de retrait existe dès la remise (HANDED_OVER) : on l'affiche
        // en pleine largeur sous le bouton QR (carte riche : digits + copier +
        // régénérer + explication), le QR restant accessible jusqu'au retrait.
        'HANDED_OVER' ||
        'IN_TRANSIT' when bid.confirmationCode != null => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QrTalonButton(bid: bid, compact: true),
            const SizedBox(height: DonySpacing.base),
            TalonRetraitCodeView(
              bidId: bid.id,
              initialCode: bid.confirmationCode!,
              refreshCount: bid.confirmationCodeRefreshCount,
              refreshWindowStart: bid.confirmationCodeRefreshWindowStart,
            ),
          ],
        ),
        'HANDED_OVER' || 'IN_TRANSIT' => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QrTalonButton(bid: bid, compact: true),
            const SizedBox(height: DonySpacing.base),
            const _InTransitWaitingPlaceholder(),
          ],
        ),
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
      icon: Icon(Icons.qr_code_2_rounded, size: 20, color: cs.primary),
      label: Text(
        compact
            ? 'QR du colis'
            : 'QR du colis — à présenter ou coller sur le colis',
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

    final weight = bid.weightKg != null
        ? '${bid.weightKg!.toStringAsFixed(1)} kg'
        : '—';
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
