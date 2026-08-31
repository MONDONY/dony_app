import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Explique la devise immuable appliquée par le serveur à une publication.
///
/// Le cache Hive sert uniquement à afficher la préférence active ; la devise
/// n'est jamais ajoutée au payload du formulaire.
class CurrencyPublishBanner extends StatelessWidget {
  const CurrencyPublishBanner({super.key, required this.currency});

  /// Bannière alimentée par la devise active en cache.
  factory CurrencyPublishBanner.active({Key? key}) =>
      CurrencyPublishBanner(key: key, currency: ActiveCurrency.current);

  final SupportedCurrency? currency;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasCurrency = currency != null;
    final title = hasCurrency
        ? 'Publié en ${currency!.displayName} (${currency!.code})'
        : 'Devise à confirmer';
    final description = hasCurrency
        ? 'Les utilisateurs dans une autre devise voient un prix converti. '
              'Le paiement reste dans cette devise.'
        : 'La devise de publication est vérifiée par Yadony avant publication.';
    final semantics = hasCurrency
        ? 'Publication en ${currency!.displayName}, devise ${currency!.code}. '
              'Les utilisateurs dans une autre devise voient un prix converti. '
              'Le paiement reste dans cette devise.'
        : 'Devise de publication à confirmer par Yadony avant publication.';

    return Semantics(
      container: true,
      label: semantics,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('currency-publish-banner'),
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
                      title,
                      style: tt.titleMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DonySpacing.xs),
                    Text(
                      description,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
