import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────
// ShipmentCard — carte colis expéditeur (Mes envois)
//
// Design direction: « Éditorial calme » (cohérent avec TripCard)
// • Route en headline Hanken Grotesk bold avec flèche primaire.
// • Badge statut pill (dot + label uppercase) — même pattern que TripCard.
// • ShipmentStepper 4 étapes (icônes Material en pastilles) pour les
//   statuts post-acceptation ; masqué en pré-acceptation.
// • Footer DonyAvatar sm + nom voyageur + CTA contextuel.
// • Motion : fadeIn + slideY staggeré par index, easeOutCubic 300 ms.
// ─────────────────────────────────────────────────────────────

/// Maps a bid status to its parcel stepper step (1–4), or null for
/// pre-acceptance statuses that should not show the stepper.
///
/// Steps:
///   1 = ACCEPTED   — Remis au voyageur à venir
///   2 = HANDED_OVER — Colis remis
///   3 = IN_TRANSIT  — En vol
///   4 = COMPLETED   — Livré
int? shipmentStepFor(String status) => switch (status) {
      'ACCEPTED' => 1,
      'HANDED_OVER' => 2,
      'IN_TRANSIT' => 3,
      'COMPLETED' => 4,
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
  ({Color bg, Color fg, String label}) _badge(ColorScheme cs) =>
      switch (bid.status) {
        'IN_TRANSIT' => (
            bg: cs.infoLight,
            fg: cs.info,
            label: 'EN TRANSIT',
          ),
        'HANDED_OVER' => (
            bg: cs.infoLight,
            fg: cs.info,
            label: 'REMIS',
          ),
        'ACCEPTED' => (
            bg: cs.warningLight,
            fg: cs.warning,
            label: 'À REMETTRE',
          ),
        'PENDING' || 'AWAITING_PAYMENT' || 'PAYMENT_ESCROWED' => (
            bg: cs.warningLight,
            fg: cs.warning,
            label: 'EN ATTENTE',
          ),
        'COMPLETED' => (
            bg: cs.successLight,
            fg: cs.success,
            label: 'LIVRÉ',
          ),
        'CANCELLED' || 'REJECTED' || 'NO_SHOW' || 'EXPIRED' ||
        'PARCEL_REFUSED' => (
            bg: DonyColors.neutral100,
            fg: cs.onSurfaceVariant,
            label: 'TERMINÉ',
          ),
        _ => (
            bg: DonyColors.neutral100,
            fg: cs.onSurfaceVariant,
            label: bid.status,
          ),
      };

  /// Label describing the current stepper step.
  String _stepLabel() => switch (bid.status) {
        'ACCEPTED' => 'Remise au voyageur à venir',
        'HANDED_OVER' => 'Colis remis au voyageur',
        'IN_TRANSIT' =>
          'En vol vers ${bid.arrivalCity ?? 'destination'}',
        'COMPLETED' => 'Livré à destination',
        _ => '',
      };

  /// CTA label for the footer action link.
  String _ctaLabel() => switch (bid.status) {
        'IN_TRANSIT' || 'HANDED_OVER' => 'Suivre le colis →',
        'ACCEPTED' => 'Voir le QR →',
        _ => 'Détails →',
      };

  /// Whether the CTA should be muted (disabled statuses).
  bool get _isDisabled => switch (bid.status) {
        'REJECTED' ||
        'CANCELLED' ||
        'NO_SHOW' ||
        'EXPIRED' ||
        'PARCEL_REFUSED' =>
          true,
        _ => false,
      };

  /// Format weight with comma decimal separator: '4,5 kg' or '5 kg'.
  String _weightLabel() {
    final kg = bid.weightKg;
    if (kg == null) {
      return '— kg';
    }
    final whole = kg.truncateToDouble() == kg;
    return '${kg.toStringAsFixed(whole ? 0 : 1).replaceAll('.', ',')} kg';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final badge = _badge(cs);
    final step = shipmentStepFor(bid.status);
    final hasStep = step != null;
    final stepLabel = _stepLabel();

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
              'Colis ${_weightLabel()}'
              '${bid.recipientName != null ? ' · pour ${bid.recipientName}' : ''}',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

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
                  _ctaLabel(),
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
        .animate(
          delay: Duration(milliseconds: DonyCurve.staggerMs * index),
        )
        .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────
// ShipmentStepper — 4-step parcel journey stepper
//
// Steps: 1=Remis · 2=Embarqué · 3=En vol · 4=Livraison
// Done (i < currentStep) → primary background + check icon
// Current (i == currentStep) → primary background + step icon + blue200 border
// pending (i > currentStep) → neutral100 background + step icon (onSurfaceVariant)
// Connectors: primary if done, neutral100 if todo
// ─────────────────────────────────────────────────────────────

class ShipmentStepper extends StatelessWidget {
  const ShipmentStepper({super.key, required this.currentStep});

  /// Current step in the range 1..4.
  final int currentStep;

  static const _icons = <IconData?>[
    Icons.check_rounded, // step 1 — handover
    null,                // step 2 — embarked (uses _iconAssets[1])
    Icons.flight_rounded, // step 3 — in transit
    Icons.home_rounded,   // step 4 — delivered
  ];

  static const _iconAssets = <String?>[
    null,        // step 1
    'package',   // step 2 — embarked (colis)
    null,        // step 3
    null,        // step 4
  ];

  static const _labels = [
    'Remis',
    'Embarqué',
    'En vol',
    'Livraison',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < 4; i++) ...[
          _StepPastille(
            stepNumber: i + 1,
            currentStep: currentStep,
            icon: _icons[i],
            iconAsset: _iconAssets[i],
            label: _labels[i],
            cs: cs,
            tt: tt,
          ),
          if (i < 3)
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
                    borderRadius:
                        BorderRadius.circular(DonyRadius.full),
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
    required this.icon,
    required this.label,
    required this.cs,
    required this.tt,
    this.iconAsset,
  }) : assert(icon != null || iconAsset != null);

  final int stepNumber;
  final int currentStep;
  final IconData? icon;
  final String? iconAsset;
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
    // own icon (Material) or asset (e.g. 'package' for the colis step).
    final IconData displayIcon;
    final String? displayAsset;
    BoxDecoration decoration;

    if (_isDone) {
      bg = cs.primary;
      iconColor = cs.onPrimary;
      displayIcon = Icons.check_rounded;
      displayAsset = null;
      decoration = BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      );
    } else if (_isCurrent) {
      bg = cs.primary;
      iconColor = cs.onPrimary;
      displayIcon = icon ?? Icons.check_rounded;
      displayAsset = iconAsset;
      decoration = BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: DonyColors.blue200,
          width: 3,
        ),
      );
    } else {
      // Pending/future step
      bg = DonyColors.neutral100;
      iconColor = cs.onSurfaceVariant;
      displayIcon = icon ?? Icons.check_rounded;
      displayAsset = iconAsset;
      decoration = BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: decoration,
          child: Center(
            child: displayAsset != null
                ? DonyIcon(displayAsset, size: iconSize, color: iconColor)
                : Icon(
                    displayIcon,
                    size: iconSize,
                    color: iconColor,
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: (_isDone || _isCurrent)
                ? cs.primary
                : cs.onSurfaceVariant,
            fontWeight:
                _isCurrent ? FontWeight.w700 : FontWeight.w600,
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
            bid.departureCity ?? '—',
            style: tt.headlineMedium?.copyWith(color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: cs.primary,
          ),
        ),
        Flexible(
          child: Text(
            bid.arrivalCity ?? '—',
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
            decoration: BoxDecoration(
              color: badge.fg,
              shape: BoxShape.circle,
            ),
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
