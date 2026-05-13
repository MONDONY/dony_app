import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/presentation/widgets/make_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/sender_public_profile_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class PackageRequestPreviewBottomSheet {
  const PackageRequestPreviewBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required PackageRequestSearchItem item,
    bool isOwnRequest = false,
  }) async {
    await DonyBottomSheet.show<void>(
      context,
      stickyBottom: isOwnRequest
          ? null
          : DonyButton(
              label: 'Faire une offre',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                MakeOfferBottomSheet.show(
                  context,
                  packageRequestId: item.id,
                  targetPriceEur: item.targetPriceEur,
                  weightKg: item.weightKg,
                  departureCity: item.departureCity,
                  arrivalCity: item.arrivalCity,
                );
              },
            ),
      child: _PreviewContent(item: item),
    );
  }
}

// ── Contenu principal ────────────────────────────────────────────────────────

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.item});
  final PackageRequestSearchItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CorridorHero(item: item)
            .animate()
            .fadeIn(duration: 280.ms)
            .slideY(begin: -0.06, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.base),
        _InfoGrid(item: item)
            .animate()
            .fadeIn(delay: 60.ms, duration: 260.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.base),
        _SenderCard(sender: item.sender)
            .animate()
            .fadeIn(delay: 120.ms, duration: 260.ms)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic),
        const SizedBox(height: DonySpacing.xs),
      ],
    );
  }
}

// ── Hero corridor ─────────────────────────────────────────────────────────────

class _CorridorHero extends StatelessWidget {
  const _CorridorHero({required this.item});
  final PackageRequestSearchItem item;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.lg,
        DonySpacing.base,
        DonySpacing.base,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DonyColors.blue700, DonyColors.blue900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DonyRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Ligne de trajet ────────────────────────────────────────────
          Row(
            children: [
              _CityPill(city: item.departureCity),
              Expanded(child: _FlightPath()),
              _CityPill(city: item.arrivalCity, isDestination: true),
            ],
          ),
          const SizedBox(height: DonySpacing.lg),
          // ── Budget + date ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Budget badge
              if (item.targetPriceEur != null)
                _PriceBadge(price: item.targetPriceEur!, tt: tt)
              else
                _PriceBadge.libre(tt: tt),
              // Date pill
              _DatePill(item: item, tt: tt),
            ],
          ),
        ],
      ),
    );
  }
}

class _CityPill extends StatelessWidget {
  const _CityPill({required this.city, this.isDestination = false});
  final String city;
  final bool isDestination;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment:
          isDestination ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Icon(
          isDestination
              ? Icons.flight_land_rounded
              : Icons.flight_takeoff_rounded,
          color: Colors.white.withValues(alpha: 0.7),
          size: 15,
        ),
        const SizedBox(height: 3),
        Text(
          city,
          style: tt.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _FlightPath extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(painter: _DashedLinePainter()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.flight_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 18,
            ),
          ),
          Expanded(
            child: CustomPaint(painter: _DashedLinePainter()),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashWidth = 4.0;
    const dashGap = 4.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price, required this.tt})
      : _libre = false;
  const _PriceBadge.libre({required TextTheme tt})
      : price = 0,
        // ignore: prefer_initializing_formals
        tt = tt,
        _libre = true;

  final double price;
  final TextTheme tt;
  final bool _libre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md, vertical: DonySpacing.xs + 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        boxShadow: [
          BoxShadow(
            color: DonyColors.blue900.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.payments_rounded, color: DonyColors.primary, size: 14),
          const SizedBox(width: DonySpacing.xs),
          Text(
            _libre ? 'Libre' : '${price.toStringAsFixed(0)} €',
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: DonyColors.primary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.item, required this.tt});
  final PackageRequestSearchItem item;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('d MMM', 'fr').format(item.desiredDate).toLowerCase();
    final toleranceStr =
        item.dateToleranceDays > 0 ? ' ±${item.dateToleranceDays}j' : '';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md, vertical: DonySpacing.xs + 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded,
              color: Colors.white.withValues(alpha: 0.9), size: 13),
          const SizedBox(width: DonySpacing.xs),
          Text(
            '$dateStr$toleranceStr',
            style: tt.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grille 2×2 infos ──────────────────────────────────────────────────────────

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.item});
  final PackageRequestSearchItem item;

  String get _sizeLabel => switch (item.parcelSize) {
        ParcelSize.small => 'Petit · S',
        ParcelSize.medium => 'Moyen · M',
        ParcelSize.large => 'Grand · L',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.scale_rounded,
                label: 'Poids',
                value: '${item.weightKg.toStringAsFixed(0)} kg',
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _InfoTile(
                icon: Icons.open_in_full_rounded,
                label: 'Taille',
                value: _sizeLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: DonySpacing.sm),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: item.contentCategory.icon,
                label: 'Catégorie',
                value: item.contentCategory.label,
                isUrgent: item.contentCategory.isUrgent,
              ),
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: _InfoTile(
                icon: Icons.pin_drop_rounded,
                label: item.pickupNeighborhood != null ? 'Remise' : 'Livraison',
                value: item.pickupNeighborhood ??
                    item.deliveryNeighborhood ??
                    'Non précisé',
              ),
            ),
          ],
        ),
      ],
    );
  }

}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isUrgent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bgColor = isUrgent
        ? cs.error.withValues(alpha: 0.06)
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);
    final iconColor = isUrgent ? cs.error : cs.primary;
    final iconBg = isUrgent
        ? cs.error.withValues(alpha: 0.12)
        : cs.primaryContainer;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(
          color: isUrgent
              ? cs.error.withValues(alpha: 0.2)
              : cs.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(DonyRadius.sm),
            ),
            child: Icon(icon, size: 16, color: iconColor),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isUrgent ? cs.error : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sender card ───────────────────────────────────────────────────────────────

class _SenderCard extends StatelessWidget {
  const _SenderCard({required this.sender});
  final SenderPublicProfile sender;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showSenderPublicProfileSheet(context, sender),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Container(
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          DonyAvatar(
            name: sender.displayName,
            size: DonyAvatarSize.lg,
            verified: sender.kycVerified,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sender.displayName,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (sender.totalRatings > 0)
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: cs.warning, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        sender.averageRating.toStringAsFixed(1),
                        style: tt.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· ${sender.totalRatings} avis',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Nouveau membre',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ),
        ),
      ),
    );
  }
}
