import 'dart:async';

import 'package:dony/core/di/injection.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bandeau informatif remplaçant l'ancien champ « valeur déclarée ». Explique
/// la politique de remboursement yadony (plafond configurable, sous conditions,
/// jamais automatique) et renvoie vers le détail des conditions (FAQ).
class ReimbursementInfoBanner extends StatelessWidget {
  const ReimbursementInfoBanner({
    super.key,
    this.onSeeConditions,
    this.analytics,
  });

  /// Optionnel : override de l'action « Voir conditions » (sinon navigue FAQ).
  final VoidCallback? onSeeConditions;

  /// Service injectable pour garder le widget testable.
  final AnalyticsService? analytics;

  void _openConditions(BuildContext context) {
    unawaited(
      (analytics ?? getIt<AnalyticsService>()).logEvent(
        AnalyticsEvents.reimbursementConditionsOpened,
      ),
    );
    final callback = onSeeConditions;
    if (callback != null) {
      callback();
    } else {
      context.push('/profile/help/faq');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: donyReimbursementCapListenable,
      builder: (context, _, _) {
        final cs = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'En cas de perte confirmée après recherche, yadony rembourse '
                      "jusqu'à $donyReimbursementCapLabel € sous conditions.",
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _openConditions(context),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          textStyle: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        child: const Text('Voir conditions'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
