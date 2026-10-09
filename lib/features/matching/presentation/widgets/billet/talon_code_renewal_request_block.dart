import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/tracking/presentation/widgets/pickup_code_request_panel.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Talon voyageur d'un colis dont le code de retrait a été bloqué ou a expiré
/// (`pickupCodeRenewalNeeded`, FLUTTER-G2). Seul l'expéditeur peut générer
/// un nouveau code : le voyageur le lui demande depuis ce bloc.
class TalonCodeRenewalRequestBlock extends StatelessWidget {
  const TalonCodeRenewalRequestBlock({super.key, required this.bidId});

  final String bidId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Container(
      key: const Key('talon-code-renewal-request'),
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.md),
        border: Border.all(color: cs.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: DonyIcon('key-round', size: 18, color: cs.warning),
              ),
              const SizedBox(width: DonySpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.travelerPickupCodeRenewalTitle,
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      l.travelerPickupCodeRenewalMessage,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DonySpacing.md),
          PickupCodeRequestPanel(bidId: bidId, source: 'bid_detail'),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
