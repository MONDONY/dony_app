import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Card d'annonce/trajet — composant signature Yadony.
///
/// Affiche :
/// - Avatar du voyageur + nom + étoiles
/// - Route "Paris → Dakar" avec flèche
/// - Date de départ
/// - Prix / poids disponible
/// - Badge de statut optionnel
///
/// Usage :
/// ```dart
/// DonyTripCard(
///   travelerName: 'Ibrahima D.',
///   imageUrl: user.photoUrl,
///   route: ('Paris', 'Dakar'),
///   date: '15 mai 2025',
///   price: '8 €/kg',
///   availableKg: 5,
///   onTap: () => context.push('/trips/123'),
/// )
/// ```
class DonyTripCard extends StatelessWidget {
  const DonyTripCard({
    super.key,
    required this.travelerName,
    this.imageUrl,
    required this.route,
    required this.date,
    required this.price,
    this.availableKg,
    this.rating,
    this.badge,
    this.onTap,
    this.animationDelay,
    this.verified = false,
    this.pro = false,
  });

  final String travelerName;
  final String? imageUrl;
  final (String, String) route;
  final String date;
  final String price;
  final double? availableKg;
  final double? rating;
  final DonyBadge? badge;
  final VoidCallback? onTap;
  final Duration? animationDelay;
  final bool verified;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final card = DonyCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // — En-tête : avatar + nom + note
          Row(
            children: [
              DonyAvatar(
                name: travelerName,
                imageUrl: imageUrl,
                verified: verified,
                pro: pro,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      travelerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleLarge,
                    ),
                    if (rating != null)
                      Row(
                        children: [
                          DonyIcon('star', size: 13, color: cs.warning),
                          const SizedBox(width: DonySpacing.xxs),
                          Text(
                            '${rating!.toStringAsFixed(1)}/5',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (badge != null) Flexible(child: badge!),
            ],
          ),

          const SizedBox(height: DonySpacing.base),
          Container(height: 1, color: cs.outline),
          const SizedBox(height: DonySpacing.base),

          // — Route avec flèche animée
          _RouteDisplay(origin: route.$1, destination: route.$2),

          const SizedBox(height: DonySpacing.base),
          Container(height: 1, color: cs.outline),
          const SizedBox(height: DonySpacing.base),

          // — Pied : date + prix
          Row(
            children: [
              DonyIcon('calendar', size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: DonySpacing.xs),
              Flexible(
                child: Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const Spacer(),
              if (availableKg != null) ...[
                Text(
                  '${availableKg!.toStringAsFixed(0)} kg',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: DonySpacing.sm),
                Container(width: 1, height: 12, color: cs.outline),
                const SizedBox(width: DonySpacing.sm),
              ],
              Flexible(
                child: Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (animationDelay != null) {
      return card
          .animate(delay: animationDelay)
          .fadeIn(duration: DonyDuration.slow, curve: DonyCurve.enter)
          .slideY(
            begin: 0.04,
            duration: DonyDuration.slow,
            curve: DonyCurve.enter,
          );
    }
    return card;
  }
}

class _RouteDisplay extends StatelessWidget {
  const _RouteDisplay({required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            origin,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 32,
                height: 1.5,
                color: cs.primary.withValues(alpha: 0.3),
              ),
              const DonyEmoji.planeTakeoff(size: 16),
              Container(
                width: 32,
                height: 1.5,
                color: cs.primary.withValues(alpha: 0.3),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: cs.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            destination,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
