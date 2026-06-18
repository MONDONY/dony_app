import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Noms lisibles des moyens couverts par le rail Stripe, plateforme-aware.
///
/// Carte + PayPal partout ; Apple Pay sur iOS, Google Pay sur Android. Le choix
/// réel de l'instrument se fait dans la PaymentSheet Stripe — ces puces ne font
/// que l'annoncer lisiblement dans le sélecteur dony (les logos étaient trop
/// petits pour être identifiables).
class PaymentMethodNames extends StatelessWidget {
  const PaymentMethodNames({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final names = <String>[
      'Carte',
      if (isIOS) 'Apple Pay' else 'Google Pay',
      'PayPal',
    ];
    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        for (final n in names)
          Container(
            key: Key('payment-name-${n.toLowerCase().replaceAll(' ', '-')}'),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.full),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              n,
              style: tt.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
