import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
// ShipmentCard — carte colis expéditeur (Mes envois)
//
// Design direction: « Éditorial calme » (cohérent avec TripCard)
// • Route en headline Hanken Grotesk bold avec flèche primaire.
// • Badge statut pill (dot + label uppercase) — même pattern que TripCard.
// • ShipmentStepper 5 étapes (icônes Lucide en pastilles) pour les
//   statuts post-acceptation ; masqué en pré-acceptation.
// • Footer DonyAvatar sm + nom voyageur + CTA contextuel.
// • Motion : fadeIn + slideY staggeré par index, easeOutCubic 300 ms.
// ─────────────────────────────────────────────────────────────

/// Maps a bid status to its parcel stepper step (1–5), or null for
/// pre-acceptance statuses that should not show the stepper.
///
/// Steps:
///   1 = ACCEPTED    — Remis au voyageur à venir
///   2 = HANDED_OVER — Colis remis
///   3 = IN_TRANSIT  — En vol
///   4 = ARRIVED     — Arrivé à destination
///   5 = COMPLETED   — Livré
int? shipmentStepFor(String status) => switch (status) {
  'ACCEPTED' => 1,
  'HANDED_OVER' => 2,
  'IN_TRANSIT' => 3,
  'ARRIVED' => 4,
  'COMPLETED' => 5,
  _ => null,
};

// ─────────────────────────────────────────────────────────────
// ShipmentCard
// ─────────────────────────────────────────────────────────────

class ShipmentCard extends StatelessWidget {
  const ShipmentCard({
    super.key,
    required this.bid,
    required this.onTap,
    required this.index,
  });

  final BidModel bid;
  final VoidCallback onTap;
  final int index;

  /// Returns (bgColor, fgColor, label) for the status badge pill.
  ({Color bg, Color fg, String label}) _badge(
    ColorScheme cs,
    AppLocalizations l,
  ) => switch (bid.status) {
    'IN_TRANSIT' => (
      bg: cs.infoLight,
      fg: cs.info,
      label: l.shipmentBadgeInTransit,
    ),
    'ARRIVED' => (bg: cs.infoLight, fg: cs.info, label: l.shipmentBadgeArrived),
    'HANDED_OVER' => (
      bg: cs.infoLight,
      fg: cs.info,
      label: l.shipmentBadgeHandedOver,
    ),
    'ACCEPTED' => (
      bg: cs.warningLight,
      fg: cs.warning,
      label: l.shipmentBadgeToHandOver,
    ),
    'PENDING' || 'AWAITING_PAYMENT' || 'PAYMENT_ESCROWED' => (
      bg: cs.warningLight,
      fg: cs.warning,
      label: l.shipmentBadgeWaiting,
    ),
    'COMPLETED' => (
      bg: cs.successLight,
      fg: cs.success,
      label: l.shipmentBadgeDelivered,
    ),
    // Le motif réel plutôt qu'un « TERMINÉ » générique, qui ne disait pas
    // ce qui s'était passé. Vocabulaire aligné sur la feuille de filtre.
    'CANCELLED' => _closed(cs, l.shipmentBadgeCancelled),
    'REJECTED' => _closed(cs, l.shipmentBadgeRejected),
    'NO_SHOW' => _closed(cs, l.shipmentBadgeNoShow),
    'EXPIRED' => _closed(cs, l.shipmentBadgeExpired),
    'PARCEL_REFUSED' => _closed(cs, l.shipmentBadgeParcelRefused),
    _ => (
      bg: DonyColors.neutral100,
      fg: cs.onSurfaceVariant,
      label: bid.status,
    ),
  };

  static ({Color bg, Color fg, String label}) _closed(
    ColorScheme cs,
    String label,
  ) => (bg: DonyColors.neutral100, fg: cs.onSurfaceVariant, label: label);

  /// Label describing the current stepper step.
  String _stepLabel(AppLocalizations l) => switch (bid.status) {
    'ACCEPTED' => l.shipmentStepAcceptedLabel,
    'HANDED_OVER' => l.shipmentStepHandedOverLabel,
    'IN_TRANSIT' => l.shipmentStepInTransitLabel(
      bid.arrivalCity ?? l.shipmentDestinationFallback,
    ),
    'ARRIVED' => l.shipmentStepArrivedLabel,
    'COMPLETED' => l.shipmentStepDeliveredLabel,
    _ => '',
  };

  /// CTA label for the footer action link.
  String _ctaLabel(AppLocalizations l) => switch (bid.status) {
    'IN_TRANSIT' || 'HANDED_OVER' || 'ARRIVED' => l.shipmentCtaTrackParcel,
    'ACCEPTED' => l.shipmentCtaViewQr,
    _ => l.shipmentCtaDetails,
  };

  /// Whether the CTA should be muted (disabled statuses).
  bool get _isDisabled => switch (bid.status) {
    'REJECTED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'EXPIRED' ||
    'PARCEL_REFUSED' => true,
    _ => false,
  };

  /// Date de départ du trajet, formatée relativement à aujourd'hui — même
  /// vocabulaire que TripCard (`listingDateTodayLabel` / `Tomorrow` /
  /// `InDaysLabel`, réutilisés tels quels : préfixe de domaine partagé
  /// `listing…`, R40). `null` si l'info n'est pas disponible.
  String? _dateLabel(AppLocalizations l) {
    final date = bid.resolvedDepartureAt ?? bid.departureDate;
    if (date == null) {
      return null;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(date);
    final diff = d.difference(today).inDays;
    final dateStr = DateFormat.MMMd(l.localeName).format(date);
    if (diff == 0) {
      return l.listingDateTodayLabel(dateStr);
    }
    if (diff == 1) {
      return l.listingDateTomorrowLabel(dateStr);
    }
    if (diff > 1 && diff <= 6) {
      return l.listingDateInDaysLabel(diff, dateStr);
    }
    return DateFormat.yMMMEd(l.localeName).format(date);
  }

  /// Format weight at the effective language: '4,5 kg' in French, '4.5 kg'
  /// in English.
  String _weightLabel(AppLocalizations l) {
    final kg = bid.weightKg;
    if (kg == null) {
      return '- kg';
    }
    return formatWeightKg(l, kg);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    final badge = _badge(cs, l);
    final step = shipmentStepFor(bid.status);
    final hasStep = step != null;
    final stepLabel = _stepLabel(l);

    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline),
          boxShadow: const [
            BoxShadow(
              color: DonyColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header row: route + badge ──
            Row(
              children: [
                Expanded(child: _RouteRow(bid: bid)),
                const SizedBox(width: DonySpacing.sm),
                _BadgePill(badge: badge),
              ],
            ),

            const SizedBox(height: DonySpacing.xs),

            // ── Meta: weight · recipient ──
            Text(
              bid.recipientName != null
                  ? l.shipmentParcelWeightForRecipientLabel(
                      _weightLabel(l),
                      bid.recipientName!,
                    )
                  : l.shipmentParcelWeightLabel(_weightLabel(l)),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Date du trajet ──
            if (_dateLabel(l) case final dateLabel?) ...[
              const SizedBox(height: DonySpacing.xxs + 1),
              Row(
                children: [
                  DonyIcon('calendar', size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: DonySpacing.xxs + 1),
                  Flexible(
                    child: Text(
                      dateLabel,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // ── Stepper (post-acceptance only) ──
            if (hasStep) ...[
              const SizedBox(height: DonySpacing.md),
              ShipmentStepper(currentStep: step),
              if (stepLabel.isNotEmpty) ...[
                const SizedBox(height: DonySpacing.xs),
                Text(
                  stepLabel,
                  style: tt.bodySmall?.copyWith(
                    color: badge.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],

            const SizedBox(height: DonySpacing.md),

            // ── Divider ──
            Divider(height: 1, thickness: 1, color: cs.outline),

            const SizedBox(height: DonySpacing.sm),

            // ── Footer: traveler avatar + name | CTA ──
            Row(
              children: [
                if (bid.travelerName != null) ...[
                  DonyAvatar(
                    name: bid.travelerName!,
                    imageUrl: bid.travelerAvatarUrl,
                    size: DonyAvatarSize.sm,
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      bid.travelerName!,
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                Text(
                  _ctaLabel(l),
                  style: tt.titleSmall?.copyWith(
                    color: _isDisabled ? cs.onSurfaceVariant : cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return card
        .animate(delay: Duration(milliseconds: DonyCurve.staggerMs * index))
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────
// ShipmentStepper — 5-step parcel journey stepper
//
// Steps: 1=Remis · 2=Embarqué · 3=En vol · 4=Arrivé · 5=Livraison
// Done (i < currentStep) → primary background + check icon
// Current (i == currentStep) → primary background + step icon + blue200 border
// pending (i > currentStep) → neutral100 background + step icon (onSurfaceVariant)
// Connectors: primary if done, neutral100 if todo
// ─────────────────────────────────────────────────────────────

class ShipmentStepper extends StatelessWidget {
  const ShipmentStepper({super.key, required this.currentStep});

  /// Current step in the range 1..5.
  final int currentStep;

  static const _iconAssets = <String>[
    'check', // step 1 — handover
    'package', // step 2 — embarked (colis)
    'plane', // step 3 — in transit
    'map-pin', // step 4 — arrived at destination
    'house', // step 5 — delivered
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final labels = [
      l.shipmentStepperHandedOverLabel,
      l.shipmentStepperEmbarkedLabel,
      l.shipmentStepperInFlightLabel,
      l.shipmentStepperArrivedLabel,
      l.shipmentStepperDeliveryLabel,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 5; i++) ...[
          _StepPastille(
            stepNumber: i + 1,
            currentStep: currentStep,
            iconAsset: _iconAssets[i],
            label: labels[i],
            cs: cs,
            tt: tt,
          ),
          if (i < 4)
            Expanded(
              child: Padding(
                // Vertically align connector with pastille center (24/2 = 12, minus half stroke)
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: (i + 1) < currentStep
                        ? cs.primary
                        : DonyColors.neutral100,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _StepPastille — single stepper node (pastille + label)
// ─────────────────────────────────────────────────────────────

class _StepPastille extends StatelessWidget {
  const _StepPastille({
    required this.stepNumber,
    required this.currentStep,
    required this.iconAsset,
    required this.label,
    required this.cs,
    required this.tt,
  });

  final int stepNumber;
  final int currentStep;
  final String iconAsset;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  bool get _isDone => stepNumber < currentStep;
  bool get _isCurrent => stepNumber == currentStep;

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    const iconSize = 12.0;

    final Color bg;
    final Color iconColor;
    // Done steps always show the check glyph; current/pending show this step's
    // own Lucide asset (e.g. 'package' for the colis step).
    final String displayAsset;
    BoxDecoration decoration;

    if (_isDone) {
      bg = cs.primary;
      iconColor = cs.onPrimary;
      displayAsset = 'check';
      decoration = BoxDecoration(color: bg, shape: BoxShape.circle);
    } else if (_isCurrent) {
      bg = cs.primary;
      iconColor = cs.onPrimary;
      displayAsset = iconAsset;
      decoration = BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: DonyColors.blue200, width: 3),
      );
    } else {
      // Pending/future step
      bg = DonyColors.neutral100;
      iconColor = cs.onSurfaceVariant;
      displayAsset = iconAsset;
      decoration = BoxDecoration(color: bg, shape: BoxShape.circle);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: decoration,
          child: Center(
            child: DonyIcon(displayAsset, size: iconSize, color: iconColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: (_isDone || _isCurrent) ? cs.primary : cs.onSurfaceVariant,
            fontWeight: _isCurrent ? FontWeight.w700 : FontWeight.w600,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _RouteRow — departure → arrival in bold Hanken Grotesk
// ─────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            bid.departureCity ?? '-',
            style: tt.headlineMedium?.copyWith(color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
          child: DonyIcon('arrow-right', size: 16, color: cs.primary),
        ),
        Flexible(
          child: Text(
            bid.arrivalCity ?? '-',
            style: tt.headlineMedium?.copyWith(color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _BadgePill — status pill (dot + uppercase label)
// Matches TripCard _StatusBadge pattern exactly.
// ─────────────────────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.badge});

  final ({Color bg, Color fg, String label}) badge;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: badge.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: tt.labelMedium?.copyWith(
              color: badge.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
