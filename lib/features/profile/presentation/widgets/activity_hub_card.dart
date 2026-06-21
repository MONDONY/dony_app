import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Carte hub principale (role-aware) en tête de la section « En cours » de
/// l'onglet Activité. Surface bleue gradient distincte des [DonyListSection].
class ProfileActivityHubCard extends StatelessWidget {
  const ProfileActivityHubCard({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.countLabel,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? countLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primary, cs.primary.withValues(alpha: 0.82)],
            ),
            borderRadius: BorderRadius.circular(DonyRadius.card),
          ),
          padding: const EdgeInsets.all(DonySpacing.base),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(DonyRadius.md),
                ),
                child: Center(
                  child: DonyIcon(iconAsset, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              if (countLabel != null) ...[
                const SizedBox(width: DonySpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DonySpacing.sm,
                    vertical: DonySpacing.xxs + 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(DonyRadius.full),
                  ),
                  child: Text(
                    countLabel!,
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
