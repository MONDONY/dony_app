import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Rangée de logos des moyens couverts par le rail Stripe, plateforme-aware.
///
/// Carte + PayPal partout ; Apple Pay sur iOS, Google Pay sur Android. Le choix
/// réel de l'instrument se fait dans la PaymentSheet Stripe — ces marks ne font
/// que l'annoncer dans le sélecteur dony.
class PaymentBrandMarks extends StatelessWidget {
  const PaymentBrandMarks({super.key});

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final names = <String>[
      'card',
      if (isIOS) 'apple-pay' else 'google-pay',
      'paypal',
    ];
    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        for (final n in names)
          SvgPicture.asset(
            'assets/logos/payment/$n.svg',
            key: Key('payment-mark-$n'),
            height: 16,
            semanticsLabel: _label(n),
          ),
      ],
    );
  }

  /// Label d'accessibilité par mark. Lève si un nom inconnu est ajouté à
  /// [names] sans label — un trou d'accessibilité silencieux devient un crash
  /// de dev (cf. checklist HIG « Semantics sur icônes sans label »).
  String _label(String name) => switch (name) {
        'card' => 'Carte bancaire',
        'apple-pay' => 'Apple Pay',
        'google-pay' => 'Google Pay',
        'paypal' => 'PayPal',
        _ => throw ArgumentError('unknown payment mark: $name'),
      };
}
