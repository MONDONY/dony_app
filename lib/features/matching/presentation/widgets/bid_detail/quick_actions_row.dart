import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/get_it_safe.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/share_position.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Construit l'URL publique de suivi à partir du [token].
String trackingPublicUrl(String token) {
  const base = String.fromEnvironment(
    'TRACKING_PUBLIC_URL',
    defaultValue: 'https://yadony.com/tracking',
  );
  return '$base/$token';
}

/// Partage le lien de suivi du colis via le système natif.
///
/// No-op si [bid.trackingToken] est null.
Future<void> shareTrackingLink(
  BidModel bid, {
  Rect? sharePositionOrigin,
}) async {
  final token = bid.trackingToken;
  if (token == null) {
    return;
  }

  unawaited(
    getItSafe<AnalyticsService>()?.logEvent(AnalyticsEvents.trackingLinkShared),
  );

  final url = trackingPublicUrl(token);
  await Share.share(
    'Suivez votre colis Yadony en temps réel :\n$url',
    subject: 'Suivi de colis Yadony · ${bid.trackingNumber ?? ''}',
    sharePositionOrigin: sharePositionOrigin,
  );
}

/// Ligne d'actions rapides (vue expéditeur) — tuiles « Suivi du colis » et
/// « Partager le suivi » (visible uniquement si [BidModel.trackingToken] est non-null).
class QuickActionsRow extends StatelessWidget {
  final BidModel bid;

  const QuickActionsRow({super.key, required this.bid});

  String get _corridor {
    final dep = bid.departureCity ?? '';
    final arr = bid.arrivalCity ?? '';
    return dep.isNotEmpty && arr.isNotEmpty ? '$dep → $arr' : 'Suivi du colis';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasToken = bid.trackingToken != null;

    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            iconAsset: 'package',
            label: 'Suivi du colis',
            cs: cs,
            tt: tt,
            onTap: () => showTrackingTimelineSheet(
              context,
              bidId: bid.id,
              corridor: _corridor,
              onShareTracking: hasToken
                  ? () => shareTrackingLink(
                      bid,
                      sharePositionOrigin: sharePositionOriginFor(context),
                    )
                  : null,
            ),
          ),
        ),
        if (hasToken) ...[
          const SizedBox(width: DonySpacing.sm),
          Expanded(
            child: _ActionTile(
              iconAsset: 'share-2',
              label: 'Partager le suivi',
              cs: cs,
              tt: tt,
              onTap: () => shareTrackingLink(
                bid,
                sharePositionOrigin: sharePositionOriginFor(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Tuile d'action ────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  const _ActionTile({
    this.icon,
    this.iconAsset,
    required this.label,
    required this.cs,
    required this.tt,
    required this.onTap,
  }) : assert(icon != null || iconAsset != null);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DonyRadius.card),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconAsset != null
                ? DonyIcon(iconAsset!, color: cs.primary, size: 18)
                : Icon(icon, color: cs.primary, size: 18),
            const SizedBox(width: DonySpacing.sm),
            Flexible(
              child: Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
