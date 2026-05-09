import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/bloc/active_role_cubit.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class RoleGuidanceBanner extends StatelessWidget {
  const RoleGuidanceBanner({
    super.key,
    required this.role,
    required this.hiveService,
    this.onCtaTap,
    this.forceHide = false,
  });

  final ActiveRole role;
  final HiveService hiveService;
  final VoidCallback? onCtaTap;
  final bool forceHide;

  String get _key => role == ActiveRole.traveler
      ? HiveService.kHasPublishedAsTraveler
      : HiveService.kHasPublishedAsSender;

  @override
  Widget build(BuildContext context) {
    if (forceHide) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<Box>(
      valueListenable: hiveService.listenUserPrefs(keys: [_key]),
      builder: (context, box, _) {
        final hasPublished = box.get(_key, defaultValue: false) as bool;
        if (hasPublished) {
          return const SizedBox.shrink();
        }
        return _buildBanner(context);
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    final isSender = role == ActiveRole.sender;
    final title = isSender ? 'Envoyer ton premier colis' : 'Publier ton premier trajet';
    final emoji = isSender ? '📦' : '🧭';
    final ctaLabel = isSender ? "Publier ma demande d'envoi" : 'Publier mon trajet';
    final steps = isSender
        ? [
            'Compte créé ✓',
            'Cherche un voyageur sur la carte ou publie une demande',
            'Vérifie ton identité (KYC) — requis pour payer',
          ]
        : [
            'Compte créé ✓',
            'Vérifie ton identité (KYC) — obligatoire pour voyager',
            'Publie les détails de ton trajet (date, corridor, kg dispo)',
          ];

    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.md,
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: DonyColors.primarySoft,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: DonyColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: DonySpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    color: DonyColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.sm),
          ...steps.asMap().entries.map((e) {
            final isFirst = e.key == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: DonySpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFirst ? '✓' : '${e.key + 1}.',
                    style: tt.bodySmall?.copyWith(
                      color: isFirst ? DonyColors.success : DonyColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  Expanded(
                    child: Text(
                      e.value,
                      style: tt.bodySmall?.copyWith(
                        color: isFirst ? DonyColors.textMuted : DonyColors.ink900,
                        decoration: isFirst ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: DonySpacing.md),
          GestureDetector(
            onTap: onCtaTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: DonySpacing.base,
                vertical: DonySpacing.sm,
              ),
              decoration: BoxDecoration(
                color: DonyColors.primary,
                borderRadius: BorderRadius.circular(DonyRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: DonySpacing.xs),
                  Text(
                    ctaLabel,
                    style: tt.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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
