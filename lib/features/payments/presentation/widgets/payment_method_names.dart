import 'package:dony/core/design/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Moyens couverts par le rail Stripe : logo(s) + nom, une ligne par moyen.
/// Plateforme-aware : Apple Pay (iOS) / Google Pay (Android) ; carte
/// (Visa/Mastercard) + PayPal partout. Le choix réel de l'instrument se fait
/// dans la PaymentSheet Stripe — cette liste ne fait que l'annoncer.
///
/// [compact] rend la même annonce sur **une seule rangée de logos**, sans les
/// noms : c'est la forme qu'attend une surface déjà titrée (panneau « Paiement
/// sécurisé »), où trois lignes de marques feraient de l'annonce le sujet.
class PaymentMethodNames extends StatelessWidget {
  const PaymentMethodNames({super.key, this.compact = false});

  final bool compact;

  static const double _logoHeight = 24;
  static const double _logoHeightCompact = 20;

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final walletLogo = isIOS ? 'apple-pay' : 'google-pay';
    final walletName = isIOS ? 'Apple Pay' : 'Google Pay';

    if (compact) {
      return Semantics(
        label: 'Carte, $walletName, PayPal',
        child: ExcludeSemantics(
          child: Wrap(
            spacing: DonySpacing.sm,
            runSpacing: DonySpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final logo in ['visa', 'mastercard', walletLogo, 'paypal'])
                SvgPicture.asset(
                  'assets/logos/payment/$logo.svg',
                  key: Key('payment-logo-$logo'),
                  height: _logoHeightCompact,
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, const ['visa', 'mastercard'], 'Carte'),
        _row(context, [walletLogo], walletName),
        _row(context, const ['paypal'], 'PayPal'),
      ],
    );
  }

  Widget _row(BuildContext context, List<String> logos, String name) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: Key('payment-row-${name.toLowerCase().replaceAll(' ', '-')}'),
      padding: const EdgeInsets.only(top: DonySpacing.sm),
      child: Row(
        children: [
          for (final logo in logos) ...[
            SvgPicture.asset(
              'assets/logos/payment/$logo.svg',
              height: _logoHeight,
            ),
            const SizedBox(width: DonySpacing.xs),
          ],
          Text(
            name,
            style: tt.labelMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
