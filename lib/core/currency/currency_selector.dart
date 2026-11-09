import 'package:dony/core/currency/active_currency.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_palette.dart';
import 'package:dony/l10n/l10n.dart';
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

  /// Vrai si le serveur a confirmé le rail mobile money (pawaPay) pour cette
  /// devise.
  bool get hasMobileMoneyRail =>
      availablePaymentMethods.contains(BidPaymentMethod.mobileMoney);
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

    /// Présentation de la demande de colis (étape « Le prix ») : devises
    /// regroupées par moyens de paiement, sans encart explicatif, bouton
    /// « Valider ». Les autres appelants gardent la liste historique.
    bool grouped = false,
  }) {
    final selected = ValueNotifier<SupportedCurrency>(
      initialCurrency ?? ActiveCurrency.current ?? SupportedCurrency.eur,
    );
    return DonyBottomSheet.show<SupportedCurrency>(
      context,
      title: grouped
          ? context.l10n.currencySelectorTitleRequest
          : context.l10n.currencySelectorTitle,
      child: grouped
          ? _GroupedCurrencyList(options: options, selected: selected)
          : _CurrencyOptionList(options: options, selected: selected),
      // Règle DonyButton dans bottom sheet : toujours en stickyBottom,
      // jamais dans le child scrollable.
      stickyBottom: ValueListenableBuilder<SupportedCurrency>(
        valueListenable: selected,
        builder: (context, value, _) => DonyButton(
          key: const Key('currency-selector-confirm'),
          label: grouped
              ? context.l10n.currencySelectorValidate
              : context.l10n.currencySelectorConfirm(value.code),
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

  String _subtitleFor(AppLocalizations l, SupportedCurrency currency) {
    final option = _optionFor(currency);
    if (option?.hasCardRail ?? false) return l.currencySelectorSubtitleCard;
    if (option?.hasMobileMoneyRail ?? false) {
      return l.currencySelectorSubtitleMobileMoney;
    }
    return l.currencySelectorSubtitleCashOnly;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder<SupportedCurrency>(
      valueListenable: selected,
      builder: (context, value, _) {
        final option = _optionFor(value);
        final hasCardRail = option?.hasCardRail ?? false;
        final hasMobileMoneyRail = option?.hasMobileMoneyRail ?? false;
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
                    label: '${currency.name(l)} (${currency.code})',
                    subtitle: _subtitleFor(l, currency),
                  ),
              ],
            ),
            const SizedBox(height: DonySpacing.md),
            _PaymentMethodsNotice(
              key: const Key('currency-payment-methods-notice'),
              currency: value,
              hasCardRail: hasCardRail,
              hasMobileMoneyRail: hasMobileMoneyRail,
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
    required this.hasMobileMoneyRail,
  });

  final SupportedCurrency currency;
  final bool hasCardRail;
  final bool hasMobileMoneyRail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    final String title;
    final String description;
    final String semanticsLabel;
    if (hasCardRail) {
      title = l.currencyCardAndCashAvailable(currency.code);
      description = l.currencyCardAndCashDescription;
      semanticsLabel = '${l.currencyCardAndCashAvailable(currency.name(l))}.';
    } else if (hasMobileMoneyRail) {
      title = l.currencyMobileMoneyAndCashAvailable(currency.code);
      description = l.currencyMobileMoneyAndCashDescription;
      semanticsLabel =
          '${l.currencyMobileMoneyAndCashAvailable(currency.name(l))}.';
    } else {
      title = l.currencyCashOnlyAvailable(currency.code);
      // Devise prise en charge par Stripe : la carte manque parce que le
      // voyageur n'a pas activé ses paiements. Sinon, la devise elle-même
      // n'a pas de rail carte.
      description = currency.isStripeEligible
          ? l.currencyCashOnlyDescription
          : l.currencyCashOnlyUnsupportedDescription(currency.code);
      semanticsLabel = l.currencyCashOnlyWithDescription(
        currency.name(l),
        description,
      );
    }
    final hasRail = hasCardRail || hasMobileMoneyRail;

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: hasRail ? cs.successLight : cs.infoLight,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(
              color: (hasRail ? cs.success : cs.info).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasRail
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: hasRail ? cs.success : cs.info,
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

/// Liste de la maquette « Le prix » : les devises sous trois intitulés (carte
/// et espèces, mobile money et espèces, espèces seules), chacune avec ses
/// moyens de paiement en sous-titre et une pastille de sélection.
class _GroupedCurrencyList extends StatelessWidget {
  const _GroupedCurrencyList({required this.options, required this.selected});

  final List<CurrencyPaymentOption> options;
  final ValueNotifier<SupportedCurrency> selected;

  CurrencyPaymentOption? _optionFor(SupportedCurrency currency) {
    for (final option in options) {
      if (option.currency == currency) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = WizardPalette.of(context);
    final groups = <(String, String, List<SupportedCurrency>)>[
      (l.currencySelectorSubtitleCard, l.currencySelectorRowCard, []),
      (
        l.currencySelectorSubtitleMobileMoney,
        l.currencySelectorRowMobileMoney,
        [],
      ),
      (l.currencySelectorSubtitleCashOnly, l.currencySelectorRowCash, []),
    ];
    for (final currency in SupportedCurrency.values) {
      final option = _optionFor(currency);
      final index = (option?.hasCardRail ?? false)
          ? 0
          : (option?.hasMobileMoneyRail ?? false)
          ? 1
          : 2;
      groups[index].$3.add(currency);
    }
    return ValueListenableBuilder<SupportedCurrency>(
      valueListenable: selected,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in groups)
            if (group.$3.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(
                  group.$1.toUpperCase(),
                  style: WizardPalette.text(
                    size: 10.5,
                    weight: FontWeight.w800,
                    color: p.blue,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final currency in group.$3)
                _GroupedCurrencyRow(
                  currency: currency,
                  subtitle: group.$2,
                  isSelected: currency == value,
                  onTap: () => selected.value = currency,
                ),
            ],
        ],
      ),
    );
  }
}

class _GroupedCurrencyRow extends StatelessWidget {
  const _GroupedCurrencyRow({
    required this.currency,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final SupportedCurrency currency;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = WizardPalette.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.n100)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currency.name(l)} (${currency.code})',
                      style: WizardPalette.text(
                        size: 13,
                        weight: FontWeight.w700,
                        color: p.n800,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle,
                        style: WizardPalette.text(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: p.n500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? p.blue : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? p.blue : p.border,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.white,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
