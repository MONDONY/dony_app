import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// 0 accord, 1 remise, 2 en voyage, 3 livraison, 4 livré.
int progressStepForBid(String? bidStatus) => switch (bidStatus) {
  'HANDED_OVER' || 'IN_TRANSIT' => 2,
  'ARRIVED' => 3,
  'COMPLETED' => 4,
  _ => 1,
};

class RequestProgressTimeline extends StatelessWidget {
  const RequestProgressTimeline({
    required this.travelerName,
    required this.arrivalCity,
    required this.currentStep,
    super.key,
  });

  final String travelerName;
  final String arrivalCity;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = ['Accord et paiement', 'Remise du colis à $travelerName', 'En voyage', 'Livraison à $arrivalCity'];
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.outline)),
      child: Column(
        children: [
          for (final (i, label) in labels.indexed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < currentStep ? cs.success : cs.surface,
                      border: Border.all(
                        width: 2,
                        color: i < currentStep ? cs.success
                            : i == currentStep ? cs.primary : cs.outline,
                      ),
                    ),
                    child: i < currentStep
                        ? const Center(child: DonyIcon('check', size: 11, color: Colors.white))
                        : null,
                  ),
                  if (i < labels.length - 1) Container(width: 2, height: 22, color: cs.outlineVariant),
                ]),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Text(label, style: TextStyle(
                    fontSize: 13,
                    fontWeight: i <= currentStep ? FontWeight.w700 : FontWeight.w500,
                    color: i <= currentStep ? cs.onSurface : cs.onSurfaceVariant,
                  )),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
