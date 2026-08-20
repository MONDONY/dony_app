import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';

Set<BidPaymentMethod> _paymentMethodsFromJson(List<dynamic>? values) {
  // Sens décodage dérivé de [BidPaymentMethodApi.apiValue], la seule source
  // publique du mapping @JsonValue — jamais de littéraux dupliqués ici.
  final byWireValue = {
    for (final method in BidPaymentMethod.values) method.apiValue: method,
  };
  return (values ?? const [])
      .map((value) => byWireValue[value as String])
      .whereType<BidPaymentMethod>()
      .toSet();
}

/// Devise et moyens de paiement qui en découlent, tels qu'exposés par le
/// serveur.
///
/// Le calcul (carte disponible seulement si le voyageur a Stripe Connect ET
/// que la devise est prise en charge par Stripe, espèces toujours possible)
/// vit uniquement côté backend (`AnnouncementPaymentRails.availableFor`).
/// Cette classe transporte le résultat déjà tranché : elle ne le recalcule
/// jamais côté client.
class CurrencyPaymentOption {
  const CurrencyPaymentOption({
    required this.currency,
    required this.availablePaymentMethods,
  });

  final SupportedCurrency currency;
  final Set<BidPaymentMethod> availablePaymentMethods;

  factory CurrencyPaymentOption.fromJson(Map<String, dynamic> json) {
    return CurrencyPaymentOption(
      currency: SupportedCurrency.fromCodeOrDefault(
        json['currency'] as String?,
      ),
      availablePaymentMethods: _paymentMethodsFromJson(
        json['availablePaymentMethods'] as List<dynamic>?,
      ),
    );
  }

  /// Vrai si le serveur a confirmé le rail carte pour cette devise.
  bool get hasCardRail =>
      availablePaymentMethods.contains(BidPaymentMethod.stripe);
}

/// Sélecteur de devise partagé — utilisé par les formulaires de création
/// (trajet, demande de colis) et par les Réglages.
///
/// Liste les 7 devises de [SupportedCurrency.values] et annonce, pour la
/// devise choisie, les moyens de paiement qui en découlent. Cette annonce
/// s'appuie strictement sur [options] — un résultat déjà calculé par le
/// serveur — et non sur une règle rejouée côté Flutter. Une devise absente
/// de [options] est traitée comme "espèces uniquement" : mieux vaut sous
/// promettre que d'annoncer un rail carte que le serveur n'a pas confirmé.
abstract final class CurrencySelector {
  /// Ouvre le sélecteur dans une bottom sheet standard Yadony. Retourne la
  /// devise choisie, ou `null` si l'utilisateur ferme la feuille sans
  /// confirmer.
  static Future<SupportedCurrency?> show(
    BuildContext context, {
    required List<CurrencyPaymentOption> options,
    SupportedCurrency? initialCurrency,
  }) {
    final selected = ValueNotifier<SupportedCurrency>(
      initialCurrency ?? ActiveCurrency.current ?? SupportedCurrency.eur,
    );
    return DonyBottomSheet.show<SupportedCurrency>(
      context,
      title: 'Choisir une devise',
      child: _CurrencyOptionList(options: options, selected: selected),
      // Règle DonyButton dans bottom sheet : toujours en stickyBottom,
      // jamais dans le child scrollable.
      stickyBottom: ValueListenableBuilder<SupportedCurrency>(
        valueListenable: selected,
        builder: (context, value, _) => DonyButton(
          key: const Key('currency-selector-confirm'),
          label: 'Confirmer ${value.code}',
          onPressed: () => Navigator.of(context).pop(value),
        ),
      ),
    )
    // Le notifier est créé ici, hors du widget tree : il faut le
    // disposer explicitement une fois la feuille fermée.
    .whenComplete(selected.dispose);
  }
}

class _CurrencyOptionList extends StatelessWidget {
  const _CurrencyOptionList({required this.options, required this.selected});

  final List<CurrencyPaymentOption> options;
  final ValueNotifier<SupportedCurrency> selected;

  CurrencyPaymentOption? _optionFor(SupportedCurrency currency) {
    for (final option in options) {
      if (option.currency == currency) {
        return option;
      }
    }
    return null;
  }

  String _subtitleFor(SupportedCurrency currency) {
    final hasCardRail = _optionFor(currency)?.hasCardRail ?? false;
    return hasCardRail ? 'Carte et espèces' : 'Espèces uniquement';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SupportedCurrency>(
      valueListenable: selected,
      builder: (context, value, _) {
        final hasCardRail = _optionFor(value)?.hasCardRail ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DonyRadioGroup<SupportedCurrency>(
              value: value,
              onChanged: (currency) {
                if (currency != null) {
                  selected.value = currency;
                }
              },
              options: [
                for (final currency in SupportedCurrency.values)
                  DonyRadioOption<SupportedCurrency>(
                    value: currency,
                    label: '${currency.displayName} (${currency.code})',
                    subtitle: _subtitleFor(currency),
                  ),
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            _PaymentMethodsNotice(
              key: const Key('currency-payment-methods-notice'),
              currency: value,
              hasCardRail: hasCardRail,
            ),
          ],
        );
      },
    );
  }
}

/// Explique, pour la devise choisie, les moyens de paiement qui en
/// découlent, avec le pourquoi quand la carte n'est pas proposée.
class _PaymentMethodsNotice extends StatelessWidget {
  const _PaymentMethodsNotice({
    super.key,
    required this.currency,
    required this.hasCardRail,
  });

  final SupportedCurrency currency;
  final bool hasCardRail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = hasCardRail
        ? 'Carte et espèces disponibles en ${currency.code}'
        : 'Espèces uniquement en ${currency.code}';
    final description = hasCardRail
        ? 'Le voyageur peut accepter un paiement par carte ou en espèces pour cette devise.'
        : 'Le paiement par carte n\'est pas proposé pour cette devise : soit le '
              'voyageur n\'a pas encore activé les paiements Yadony, soit '
              '${currency.code} n\'est pas prise en charge par Stripe. Seul le '
              'paiement en espèces sera possible.';
    final semanticsLabel = hasCardRail
        ? 'Carte et espèces disponibles en ${currency.displayName}.'
        : 'Espèces uniquement en ${currency.displayName}. $description';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: hasCardRail ? cs.successLight : cs.infoLight,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: (hasCardRail ? cs.success : cs.info).withValues(
                alpha: 0.35,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasCardRail
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: hasCardRail ? cs.success : cs.info,
              ),
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
