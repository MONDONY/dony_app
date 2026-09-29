import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Encart qui explique pourquoi un mode de paiement est indisponible à la
/// publication d'un trajet, avec le lien pour le configurer quand c'est
/// possible.
///
/// Même habillage que `CashCommissionNotice`, qu'il côtoie dans la section
/// « Modes de paiement acceptés ». Sans [ctaLabel], l'encart ne fait
/// qu'informer : un pays que Stripe ne couvre pas ou une devise sans carte ne
/// se règlent pas depuis l'application, inutile d'y inviter.
class PaymentSetupNotice extends StatelessWidget {
  // Un lien sans action, ou une action sans lien, ne mène nulle part.
  const PaymentSetupNotice({
    super.key,
    required this.message,
    this.ctaLabel,
    this.ctaKey,
    this.onCtaTap,
  }) : assert((ctaLabel == null) == (onCtaTap == null));

  final String message;
  final String? ctaLabel;
  final Key? ctaKey;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DonySpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonyIcon('info', size: 18, color: cs.primary),
          const SizedBox(width: DonySpacing.sm),
          // Le lien passe sous le texte, jamais à côté : il reste lisible
          // quelle que soit la taille de police choisie par l'utilisateur.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface,
                    height: 1.45,
                  ),
                ),
                if (ctaLabel != null)
                  TextButton(
                    key: ctaKey,
                    onPressed: onCtaTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            ctaLabel!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        Icon(DonyIcons.arrowRight, size: 16, color: cs.primary),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
