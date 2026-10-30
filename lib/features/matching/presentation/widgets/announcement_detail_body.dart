import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:dony/features/matching/presentation/widgets/billet/trip_billet_card.dart';
import 'package:dony/features/matching/presentation/widgets/trip_owner/trip_detail_sections.dart';
import 'package:dony/features/matching/presentation/widgets/trip_suitcase_gauge.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Corps de détail d'un trajet (hero, capacité/prix, colis, lieux de remise,
/// fenêtre de remise, paiements, contenus acceptés/refusés, note expéditeurs).
///
/// Utilisé par l'écran plein écran du propriétaire (TripOwnerDetailScreen).
/// Ne contient AUCUNE action — uniquement la présentation des données du trajet.
class AnnouncementDetailBody extends StatelessWidget {
  final AnnouncementModel a;

  /// Ouvre l'édition du trajet pour y ajouter la carte, puis recharge le
  /// détail. Fourni par l'écran du propriétaire. Sans lui, l'encart d'un
  /// trajet en espèces sur un compte Stripe déjà activé n'a pas d'action.
  final VoidCallback? onEnableCardOnTrip;

  const AnnouncementDetailBody({
    super.key,
    required this.a,
    this.onEnableCardOnTrip,
  });

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
        const SizedBox(height: DonySpacing.sm),

        // ── Valises : kilos restants dans chacune ───────────────────────────
        if (TripCapacity.fromAnnouncement(a) case final capacity?) ...[
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
          const SizedBox(height: DonySpacing.sm),
        ],

        // ── Colis : acceptés vs en attente ───────────────────────────────────
        _ParcelStatsRow(
          announcementId: a.id,
          accepted: a.confirmedParcelCount,
          pending: a.bidsCount ?? 0,
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: DonySpacing.lg),

        // ── Lieux de remise, dépôt des colis ─────────────────────────────────
        TripPlacesSection(trip: a),

        // ── Paiements ────────────────────────────────────────────────────────
        TripPaymentsSection(trip: a),

        // ── Nudge cash-only (voyageur) — active la carte pour plus de colis ──
        //
        // Muet là où Stripe n'ouvre pas de compte connecté : tous les trajets
        // y sont en espèces par construction, la bannière s'afficherait donc
        // sur chacun d'eux, indéfiniment, pour un reproche que le voyageur
        // n'a aucun moyen de lever.
        //
        // Muet aussi pour une devise sans carte (zone CFA) : activer Stripe
        // n'y changerait rien.
        //
        // Compte Stripe déjà activé : renvoyer vers l'activation faisait
        // croire qu'elle avait échoué (Sentry FLUTTER-DH). L'encart propose
        // alors d'ajouter la carte à CE trajet, par son édition.
        if (a.acceptedPaymentMethods.length == 1 &&
            a.acceptedPaymentMethods.contains(BidPaymentMethod.cash) &&
            SupportedCurrency.fromCodeOrDefault(a.currency).isStripeEligible)
          BlocBuilder<StripeAccountBloc, StripeAccountState>(
            builder: (context, stripeState) {
              if (!stripeState.connectAvailableInCountry) {
                return const SizedBox.shrink();
              }
              final stripeReady =
                  stripeState is StripeAccountReady &&
                  stripeState.accountStatus.isComplete;
              if (stripeReady && onEnableCardOnTrip == null) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DonyStatusBanner(
                    type: DonyStatusBannerType.warning,
                    iconAsset: 'triangle-alert',
                    message: stripeReady
                        ? l.listingCashOnlyCardReadyMessage
                        : l.listingCashOnlyNudgeMessage,
                    action: stripeReady
                        ? TextButton(
                            key: const Key('enable-card-on-trip-cta'),
                            onPressed: onEnableCardOnTrip,
                            child: Text(l.listingEnableCardOnTripButton),
                          )
                        : TextButton(
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

        // ── Ce que j'accepte, ce que je refuse, note aux expéditeurs ─────────
        TripConditionsSection(trip: a),
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

/// Deux compteurs côte à côte : colis acceptés (vert) vs demandes en attente
/// (ambre). Affiché sous les pills de capacité/prix dans le détail du trajet.
///
/// FLUTTER-HK : chaque tuile ouvre le détail correspondant, avec la même
/// navigation que la grille d'actions du propriétaire (`owner_action_grid`) :
/// acceptés → liste des colis du trajet, en attente → demandes à traiter.
/// Un compteur à 0 laisse la tuile inerte, sans affordance. Ce corps n'est
/// rendu que sur l'écran du propriétaire (TripOwnerDetailScreen).
class _ParcelStatsRow extends StatelessWidget {
  final String announcementId;
  final int accepted;
  final int pending;
  const _ParcelStatsRow({
    required this.announcementId,
    required this.accepted,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _ParcelStatCell(
              key: const Key('parcel-stat-accepted'),
              iconAsset: 'circle-check',
              value: accepted,
              label: l.listingAcceptedParcels(accepted),
              semanticsLabel: l.listingAcceptedParcelsSemantics(accepted),
              tint: const Color(0xFFE7F6EC),
              accent: const Color(0xFF16A34A),
              onTap: accepted > 0
                  ? () => context.push(
                      '/announcements/$announcementId/bids',
                      extra: <String, dynamic>{'title': l.tripOwnerParcelsTile},
                    )
                  : null,
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: _ParcelStatCell(
              key: const Key('parcel-stat-pending'),
              iconAsset: 'hourglass',
              value: pending,
              label: l.listingPendingParcelsLabel,
              semanticsLabel: l.listingPendingParcelsSemantics(pending),
              tint: const Color(0xFFFEF9C3),
              accent: const Color(0xFFB45309),
              onTap: pending > 0
                  ? () => context.push(
                      '/announcements/$announcementId/bids/pending',
                    )
                  : null,
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
  final String semanticsLabel;
  final Color tint;
  final Color accent;

  /// Ouvre le détail des colis concernés, avec le retour de pression standard
  /// des tuiles ([DonyPressable]). `null` → tuile inerte : pas de chevron,
  /// pas de retour de pression, pas de rôle bouton.
  final VoidCallback? onTap;

  const _ParcelStatCell({
    super.key,
    required this.iconAsset,
    required this.value,
    required this.label,
    required this.semanticsLabel,
    required this.tint,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tappable = onTap != null;
    final radius = BorderRadius.circular(DonyRadius.card);

    final content = Padding(
      padding: const EdgeInsets.all(DonySpacing.sm),
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
          if (tappable)
            DonyIcon(
              'chevron-right',
              size: 16,
              color: accent.withValues(alpha: 0.7),
            ),
        ],
      ),
    );

    final tile = Container(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: radius,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: content,
    );

    if (!tappable) return tile;

    // Le libellé d'accessibilité remplace le « 3 colis acceptés » lu en vrac.
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: DonyPressable(onTap: onTap!, child: tile),
    );
  }
}
