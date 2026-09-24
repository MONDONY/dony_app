import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Corps de détail d'un trajet (hero, capacité/prix, colis, lieux de remise,
/// fenêtre de remise, paiements, contenus acceptés/refusés, note expéditeurs).
///
/// Utilisé par l'écran plein écran du propriétaire (TripOwnerDetailScreen).
/// Ne contient AUCUNE action — uniquement la présentation des données du trajet.
class AnnouncementDetailBody extends StatelessWidget {
  final AnnouncementModel a;
  const AnnouncementDetailBody({super.key, required this.a});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero bleu nuit ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(DonySpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0C4A6E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.listingHeroTripLabelCaps,
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white38,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${a.departureCity} → ${a.arrivalCity}',
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (a.isUrgent) ...[
                    const DonyUrgentBadge(),
                    const SizedBox(width: DonySpacing.xs),
                  ],
                  _StatusBadge(status: a.status),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              Wrap(
                spacing: DonySpacing.xs,
                runSpacing: DonySpacing.xs,
                children: [
                  _HeroChip(
                    label: DateFormat(
                      'EEE d MMM yyyy',
                      l.localeName,
                    ).format(a.departureDate),
                  ),
                  if (a.transportMode != null)
                    _HeroChip(label: a.transportMode!.label(context.l10n)),
                  if (a.departureTime != null)
                    _HeroChip(
                      label:
                          a.departureTime! +
                          (a.arrivalTime != null ? ' → ${a.arrivalTime}' : ''),
                    ),
                ],
              ),
            ],
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
        const SizedBox(height: DonySpacing.sm),

        // ── Colis : acceptés vs en attente ───────────────────────────────────
        _ParcelStatsRow(
          accepted: a.confirmedParcelCount,
          pending: a.bidsCount ?? 0,
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: DonySpacing.lg),

        // ── Lieux de remise (orange) ─────────────────────────────────────────
        if (a.pickupAddress != null || a.deliveryAddress != null) ...[
          _BSectionTitle(
            label: l.listingPickupLocationsTitle,
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(height: DonySpacing.xs),
          if (a.pickupAddress != null)
            _BSectionRow(
              iconAsset: 'upload',
              label: l.listingPickupParcelTitleShort,
              value: a.pickupAddress!.label,
              iconBg: const Color(0xFFFFF7ED),
              iconColor: const Color(0xFFF97316),
            ).animate().fadeIn(delay: 80.ms),
          if (a.deliveryAddress != null) ...[
            const SizedBox(height: DonySpacing.xs),
            _BSectionRow(
              iconAsset: 'download',
              label: l.listingDeliveryPickupTitle,
              value: a.deliveryAddress!.label,
              iconBg: const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
            ).animate().fadeIn(delay: 100.ms),
          ],
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Dépôt des colis (sky) — date limite ──────────────────────────────
        if (a.handoverDeadline != null) ...[
          _BSectionTitle(
            label: l.listingHandoverDeadlineTitle,
            color: const Color(0xFF0284C7),
          ),
          const SizedBox(height: DonySpacing.xs),
          _BSectionRow(
            iconAsset: 'calendar',
            label: l.listingDeadlineLabel,
            value: _handoverDeadlineLabel(l, a.handoverDeadline!.toLocal()),
            iconBg: const Color(0xFFFEF9C3),
            iconColor: const Color(0xFFB45309),
          ).animate().fadeIn(delay: 110.ms),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Paiements (violet) ───────────────────────────────────────────────
        if (a.acceptedPaymentMethods.isNotEmpty) ...[
          _BSectionTitle(
            label: l.listingPaymentsAcceptedTitle,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: a.acceptedPaymentMethods.map((m) {
              final label = switch (m.apiValue) {
                'CASH' => '💵 ${l.paymentMethodCash}',
                'STRIPE' => '💳 ${l.paymentMethodCard}',
                'MOBILE_MONEY' => '📱 ${l.paymentMethodMobileMoney}',
                'WAVE' => '🌊 Wave', // i18n-ignore — nom de marque
                'ORANGE_MONEY' =>
                  '🟠 Orange Money', // i18n-ignore — nom de marque
                _ => m.apiValue,
              };
              return _BChip(
                label: label,
                bg: const Color(0xFFEDE9FE),
                fg: const Color(0xFF6D28D9),
              );
            }).toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Nudge cash-only (voyageur) — active la carte pour plus de colis ──
        //
        // Muet là où Stripe n'ouvre pas de compte connecté : tous les trajets
        // y sont en espèces par construction, la bannière s'afficherait donc
        // sur chacun d'eux, indéfiniment, pour un reproche que le voyageur
        // n'a aucun moyen de lever.
        if (a.acceptedPaymentMethods.length == 1 &&
            a.acceptedPaymentMethods.contains(BidPaymentMethod.cash))
          BlocBuilder<StripeAccountBloc, StripeAccountState>(
            builder: (context, stripeState) {
              if (!stripeState.connectAvailableInCountry) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DonyStatusBanner(
                    type: DonyStatusBannerType.warning,
                    iconAsset: 'triangle-alert',
                    message: l.listingCashOnlyNudgeMessage,
                    action: TextButton(
                      key: const Key('activate-card-payments-cta'),
                      onPressed: () =>
                          context.push('/connect/onboarding/intro'),
                      child: Text(l.listingActivateCardPaymentsButton),
                    ),
                  ).animate().fadeIn(delay: 120.ms),
                  const SizedBox(height: DonySpacing.md),
                ],
              );
            },
          ),

        // ── Ce que j'accepte (vert) ──────────────────────────────────────────
        if (a.acceptedContentTypes?.isNotEmpty ?? false) ...[
          _BSectionTitle(
            label: l.listingAcceptedContentTitle,
            color: cs.success,
          ),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: (a.acceptedContentTypes ?? [])
                .map(
                  (t) => _BChip(
                    label: contentCategoryDisplayName(l, t),
                    bg: cs.successLight,
                    fg: cs.success,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Ce que je refuse (rouge) ─────────────────────────────────────────
        if (a.refusedTypes?.isNotEmpty ?? false) ...[
          _BSectionTitle(label: l.listingRefusedContentTitle, color: cs.error),
          const SizedBox(height: DonySpacing.xs),
          Wrap(
            spacing: DonySpacing.xs,
            runSpacing: DonySpacing.xs,
            children: (a.refusedTypes ?? [])
                .map(
                  (t) => _BChip(
                    label: contentCategoryDisplayName(l, t),
                    bg: cs.errorContainer,
                    fg: cs.error,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: DonySpacing.md),
        ],

        // ── Note expéditeurs ─────────────────────────────────────────────────
        if (a.description != null && a.description!.isNotEmpty) ...[
          _BSectionTitle(
            label: l.listingSenderNoteTitle,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(height: DonySpacing.xs),
          Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEA),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              a.description!,
              style: tt.bodySmall?.copyWith(
                color: const Color(0xFF78350F),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
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
    final (label, bg, fg) = switch (status) {
      'ACTIVE' => (l.listingBadgeActive, const Color(0xFF16A34A), Colors.white),
      'DRAFT' => (l.listingBadgeDraft, const Color(0xFFB45309), Colors.white),
      'FULL' => (l.listingBadgeFull, const Color(0xFFF59E0B), Colors.white),
      'IN_PROGRESS' => (
        l.listingBadgeInProgress,
        const Color(0xFF16A34A),
        Colors.white,
      ),
      'COMPLETED' => (l.listingBadgeCompleted, Colors.white24, Colors.white),
      'CANCELLED' => (
        l.listingBadgeCancelled,
        const Color(0xFFE53935),
        Colors.white,
      ),
      _ => (status.toUpperCase(), Colors.white24, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
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

/// Deux compteurs côte à côte : colis acceptés (vert) vs demandes en attente
/// (ambre). Affiché sous les pills de capacité/prix dans le détail du trajet.
class _ParcelStatsRow extends StatelessWidget {
  final int accepted;
  final int pending;
  const _ParcelStatsRow({required this.accepted, required this.pending});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _ParcelStatCell(
              iconAsset: 'circle-check',
              value: accepted,
              label: l.listingAcceptedParcels(accepted),
              tint: const Color(0xFFE7F6EC),
              accent: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: _ParcelStatCell(
              iconAsset: 'hourglass',
              value: pending,
              label: l.listingPendingParcelsLabel,
              tint: const Color(0xFFFEF9C3),
              accent: const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelStatCell extends StatelessWidget {
  final String iconAsset;
  final int value;
  final String label;
  final Color tint;
  final Color accent;

  const _ParcelStatCell({
    required this.iconAsset,
    required this.value,
    required this.label,
    required this.tint,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DonySpacing.sm),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Center(child: DonyIcon(iconAsset, size: 17, color: accent)),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                    height: 1,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formate la plage de remise — toujours dates complètes début et fin.
String _handoverDeadlineLabel(AppLocalizations l, DateTime deadline) {
  return l.listingHandoverUntil(
    DateFormat.MMMEd(l.localeName).format(deadline),
  );
}

class _HeroChip extends StatelessWidget {
  final String label;
  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BSectionTitle extends StatelessWidget {
  final String label;
  final Color color;
  const _BSectionTitle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _BSectionRow extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;
  final Color iconBg;
  final Color iconColor;

  const _BSectionRow({
    required this.iconAsset,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(DonyRadius.sm),
          ),
          child: Center(child: DonyIcon(iconAsset, size: 16, color: iconColor)),
        ),
        const SizedBox(width: DonySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: tt.bodySmall?.copyWith(color: cs.onSurface)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _BChip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
