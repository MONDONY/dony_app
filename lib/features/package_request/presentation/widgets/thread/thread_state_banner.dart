import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:flutter/material.dart';

/// Banner d'attente affiché en bas du thread pour les statuts intermédiaires.
///
/// Match maquettes v3 :
/// - "Voyageur prépare son trajet"  (AWAITING_TRIP côté sender — 20-44-57)
/// - "En attente du paiement"        (AWAITING_PAYMENT côté traveler — 20-44-40)
/// - "Demande acceptée"              (ACCEPTED côté générique — 20-45-14)
class ThreadStateBanner extends StatelessWidget {
  const ThreadStateBanner({
    super.key,
    required this.message,
    required this.tint,
    this.icon,
    this.iconAsset,
    this.subtitle,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final String message;
  final String? subtitle;

  /// Couleur d'accent (vert success, ambre, primary blue selon contexte).
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconAsset != null
              ? DonyIcon(iconAsset!, color: tint, size: 22)
              : Icon(icon, color: tint, size: 22),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tint,
                    height: 1.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
