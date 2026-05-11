import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// **C1 — Compact horizontal** : card de demande pour le carousel near-me.
///
/// Layout :
/// ```
/// ┌────────────┬─────────────────────────┐
/// │            │ Paris → Dakar           │
/// │  108×130   │ EEE d MMM · 5 kg        │
/// │  photo     │ ─────────────────────    │
/// │            │ Marie ★4.9  [Faire offre]│
/// │ 📍 450m    │                          │
/// └────────────┴─────────────────────────┘
/// ```
class PackageRequestCompactCard extends StatelessWidget {
  const PackageRequestCompactCard({
    super.key,
    required this.item,
    required this.distanceLabel,
    this.onTap,
    this.onMakeOffer,
  });

  final PackageRequestSearchItem item;

  /// Ex : "450 m", "1.2 km" — formaté par l'appelant.
  final String distanceLabel;
  final VoidCallback? onTap;
  final VoidCallback? onMakeOffer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 108,
                  child: _CompactPhoto(
                      item: item, distanceLabel: distanceLabel),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: _CompactInfo(item: item, onMakeOffer: onMakeOffer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactPhoto extends StatelessWidget {
  const _CompactPhoto({required this.item, required this.distanceLabel});
  final PackageRequestSearchItem item;
  final String distanceLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: item.photoUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) =>
                Container(color: cs.surfaceContainerHighest),
            errorWidget: (_, _, _) => _fallback(context),
          )
        else
          _fallback(context),
        if (item.contentCategory.isUrgent)
          Positioned(
            top: 6,
            left: 6,
            child: _SmallUrgentBadge(),
          ),
        Positioned(
          left: 6,
          bottom: 6,
          child: _DistanceChip(label: distanceLabel),
        ),
      ],
    );
  }

  Widget _fallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.18),
            cs.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          item.contentCategory.emoji,
          style: const TextStyle(fontSize: 36),
        ),
      ),
    );
  }
}

class _SmallUrgentBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: DonyColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '⚡',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_rounded, color: Colors.white, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({required this.item, this.onMakeOffer});
  final PackageRequestSearchItem item;
  final VoidCallback? onMakeOffer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('d MMM', 'fr').format(item.desiredDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${item.departureCity} → ${item.arrivalCity}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '$dateStr · ${item.weightKg.toStringAsFixed(0)} kg · ${item.contentCategory.label}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.sender.displayName}${item.sender.totalRatings > 0 ? '  ★${item.sender.averageRating.toStringAsFixed(1)}' : ''}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (item.targetPriceEur != null)
              Text(
                '${item.targetPriceEur!.toStringAsFixed(0)} €',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (onMakeOffer != null)
          GestureDetector(
            onTap: onMakeOffer,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Faire offre',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded,
                      color: cs.onPrimary, size: 12),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
