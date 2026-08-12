import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter/material.dart';

/// Affichage lecture-seule des moyens de paiement acceptés par l'expéditeur.
///
/// Rendu sous forme de chips (icône + label) dans l'ordre canonique
/// (carte → cash → mobile money). Utilisé partout où un voyageur consulte une
/// demande avant de faire son offre (détail public, aperçu carte…).
class PaymentMethodsChips extends StatelessWidget {
  const PaymentMethodsChips({required this.methods, super.key});

  final Set<PaymentMethod> methods;

  @override
  Widget build(BuildContext context) {
    final ordered = PaymentMethod.canonicalOrder
        .where(methods.contains)
        .toList();
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: ordered.map((m) => _PaymentMethodChip(method: m)).toList(),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({required this.method});

  final PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      key: Key('payment-method-chip-${method.wireName.toLowerCase()}'),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.base,
        vertical: DonySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.full),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(method.icon, size: 14, color: cs.primary),
          const SizedBox(width: DonySpacing.xs),
          Text(
            method.displayLabel,
            style: tt.labelMedium!.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
