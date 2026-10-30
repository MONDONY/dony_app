import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/features/matching/presentation/widgets/billet/trip_billet_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_suitcase_gauge.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Tête de l'écran du trajet vu par son voyageur : le billet (badge d'état,
/// badge Urgent), la ligne surplus d'un trajet dédié, les deux pastilles
/// kilos et prix, la jauge des valises. Rendu inchangé de l'ancien corps de
/// détail ; les lieux, les paiements et les conditions vivent dans les
/// sheets « Votre trajet », les compteurs de colis dans les cartes Demandes
/// et Colis, l'encart « espèces seules » dans « À traiter ».
///
/// Sans action : uniquement la présentation des données du trajet.
class TripOwnerHeader extends StatelessWidget {
  final AnnouncementModel a;

  const TripOwnerHeader({super.key, required this.a});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Billet du trajet (FLUTTER-PY) ───────────────────────────────────
        // Même billet que la feuille vue par un expéditeur : l'ancien en-tête
        // en dégradé bleu nuit faisait « généré ». Les kilos sont repris en
        // grand juste en dessous, le talon ne les répète pas.
        TripBilletCard(
          announcement: a,
          showKg: false,
          notchColor: Theme.of(context).scaffoldBackgroundColor,
          trailing: Padding(
            padding: const EdgeInsets.only(
              top: DonySpacing.xs,
              right: DonySpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (a.isUrgent) ...[
                  const DonyUrgentBadge(),
                  const SizedBox(width: DonySpacing.xs),
                ],
                _StatusBadge(status: a.status),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 250.ms),
        const SizedBox(height: DonySpacing.md),

        // ── Répartition capacité (trajet dédié au surplus ouvert) ───────────
        if (a.surplusPublished) ...[
          _SurplusSplitRow(
            reservedKg: a.reservedKg,
            openKg: a.availableKg,
          ).animate().fadeIn(delay: 40.ms),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── 2 info pills (capacité · prix) ───────────────────────────────────
        IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _InfoPill(
                  value: a.capacityUnit == 'KG_FREE'
                      ? l.tripKgFree
                      : '${a.availableKg.toStringAsFixed(0)} kg',
                  label: l.listingCapacityAvailableSuffix,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: _InfoPill(
                  // Garde sur hasKgPrice (valeur > 0), pas sur la seule
                  // nullité : voir announcement_detail_screen.dart pour le
                  // même raisonnement (écran propriétaire, 0 est la valeur
                  // trompeuse à écarter, pas l'absence).
                  value: a.pricingMode == 'MIXED'
                      ? l.listingPriceGridShort
                      : (a.hasKgPrice && a.pricePerKg != null)
                      ? '${formatPriceIn(a.pricePerKg!, a.currency)}/kg'
                      : l.listingPriceUnavailableShort,
                  label: a.pricingMode == 'MIXED'
                      ? l.listingPricingSuffixTarifaire
                      : l.listingPricingSuffixPrix,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 60.ms),

        // ── Valises : kilos restants dans chacune ───────────────────────────
        if (TripCapacity.fromAnnouncement(a) case final capacity?) ...[
          const SizedBox(height: DonySpacing.sm),
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.listingSuitcaseCapacityLabel(
                    capacity.count,
                    capacity.unitKg,
                  ),
                  style: tt.titleMedium,
                ),
                const SizedBox(height: DonySpacing.md),
                TripSuitcaseGauge(capacity: capacity),
              ],
            ),
          ).animate().fadeIn(delay: 70.ms),
        ],
      ],
    );
  }
}

// ── Widgets helpers du corps de détail ────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // Posé sur le billet clair : fond teinté, texte foncé de la même famille.
    const green = (Color(0xFFE8F5EE), Color(0xFF166534));
    const amber = (Color(0xFFFEF3C7), Color(0xFF92400E));
    final neutral = (cs.surfaceContainerHighest, cs.onSurfaceVariant);
    final (label, (bg, fg)) = switch (status) {
      'ACTIVE' => (l.listingBadgeActive, green),
      'DRAFT' => (l.listingBadgeDraft, amber),
      'FULL' => (l.listingBadgeFull, amber),
      'IN_PROGRESS' => (l.listingBadgeInProgress, green),
      'COMPLETED' => (l.listingBadgeCompleted, neutral),
      'CANCELLED' => (
        l.listingBadgeCancelled,
        (cs.error.withValues(alpha: 0.12), cs.error),
      ),
      _ => (status.toUpperCase(), neutral),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Répartition « X kg réservés · Y kg ouverts » affichée sur un trajet dédié
/// dont le surplus a été publié au public.
class _SurplusSplitRow extends StatelessWidget {
  final double reservedKg;
  final double openKg;
  const _SurplusSplitRow({required this.reservedKg, required this.openKg});

  String _fmt(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.successLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.success.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          DonyIcon('globe', size: 18, color: cs.success),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l.listingReservedKgLabel(_fmt(reservedKg)),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                  TextSpan(
                    text: ' · ',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  TextSpan(
                    text: l.listingOpenKgLabel(_fmt(openKg)),
                    style: tt.bodyMedium?.copyWith(
                      color: cs.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String value;
  final String label;
  const _InfoPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
