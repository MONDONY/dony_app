import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Liste verticale des moyens couverts par le rail Stripe : logo(s) + nom, une
/// ligne par moyen. Plateforme-aware : Apple Pay (iOS) / Google Pay (Android) ;
/// carte (Visa/Mastercard) + PayPal partout. Le choix réel de l'instrument se
/// fait dans la PaymentSheet Stripe — cette liste ne fait que l'annoncer.
class PaymentMethodNames extends StatelessWidget {
  const PaymentMethodNames({super.key});

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, const ['visa', 'mastercard'], 'Carte'),
        _row(
          context,
          [isIOS ? 'apple-pay' : 'google-pay'],
          isIOS ? 'Apple Pay' : 'Google Pay',
        ),
        _row(context, const ['paypal'], 'PayPal'),
      ],
    );
  }

  Widget _row(BuildContext context, List<String> logos, String name) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: Key('payment-row-${name.toLowerCase().replaceAll(' ', '-')}'),
      padding: const EdgeInsets.only(top: DonySpacing.xs),
      child: Row(
        children: [
          for (final logo in logos) ...[
            SvgPicture.asset('assets/logos/payment/$logo.svg', height: 16),
            const SizedBox(width: DonySpacing.xs),
          ],
          Text(
            name,
            style: tt.labelMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
