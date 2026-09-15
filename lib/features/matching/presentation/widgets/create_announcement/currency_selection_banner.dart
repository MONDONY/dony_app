import 'dart:async';

import 'package:dony/core/currency/currency_selector.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bannière interactive : annonce la devise choisie pour la publication et
/// ouvre le sélecteur partagé (`CurrencySelector`) au tap. Remplace l'ancienne
/// `CurrencyPublishBanner` statique — la devise n'était encore jamais
/// envoyée au serveur avant ce lot, elle se choisit désormais explicitement.
class CurrencySelectionBanner extends StatelessWidget {
  const CurrencySelectionBanner({super.key, required this.currencyNotifier});

  final ValueNotifier<SupportedCurrency> currencyNotifier;

  /// Moyens de paiement prévisualisés par devise. `stripeConfigured` reflète
  /// le compte Connect du créateur (seul voyageur concerné à cette étape) ;
  /// l'éligibilité Stripe par devise suit `SupportedCurrency.isStripeEligible`
  /// (verbatim contrainte serveur). Aperçu client uniquement : le serveur
  /// reste seul décideur au paiement réel.
  List<CurrencyPaymentOption> _options(bool stripeConfigured) => [
    for (final currency in SupportedCurrency.values)
      CurrencyPaymentOption(
        currency: currency,
        availablePaymentMethods: {
          BidPaymentMethod.cash,
          if (stripeConfigured && currency.isStripeEligible)
            BidPaymentMethod.stripe,
        },
      ),
  ];

  Future<void> _openSelector(BuildContext context) async {
    final stripeState = context.read<StripeAccountBloc>().state;
    final stripeConfigured =
        stripeState is StripeAccountReady &&
        stripeState.accountStatus.isComplete;
    final selected = await CurrencySelector.show(
      context,
      options: _options(stripeConfigured),
      initialCurrency: currencyNotifier.value,
    );
    if (selected != null) {
      currencyNotifier.value = selected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ValueListenableBuilder<SupportedCurrency>(
      valueListenable: currencyNotifier,
      builder: (context, currency, _) {
        final semanticsLabel =
            'Devise de publication : ${currency.displayName}, '
            '${currency.code}. Les utilisateurs dans une autre devise voient '
            'un prix converti. Le paiement reste dans cette devise. '
            'Bouton, modifier la devise.';
        return Semantics(
          container: true,
          button: true,
          label: semanticsLabel,
          child: ExcludeSemantics(
            child: InkWell(
              key: const Key('trip-currency-selector-row'),
              borderRadius: BorderRadius.circular(DonyRadius.card),
              onTap: () => unawaited(_openSelector(context)),
              child: Container(
                padding: const EdgeInsets.all(DonySpacing.base),
                decoration: BoxDecoration(
                  color: cs.infoLight,
                  borderRadius: BorderRadius.circular(DonyRadius.card),
                  border: Border.all(color: cs.info.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: cs.info),
                    const SizedBox(width: DonySpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Publié en ${currency.displayName} (${currency.code})',
                            style: tt.titleMedium?.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            'Les utilisateurs dans une autre devise voient un prix '
                            'converti. Le paiement reste dans cette devise.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      'Changer',
                      style: tt.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
