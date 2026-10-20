import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/currency/country_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Recherche du pays du compte mobile money qui paie, en autocomplétion.
///
/// Propose les pays servis ([MobileMoneyCountries.available]) puis ceux
/// annoncés ([MobileMoneyCountries.upcoming]), filtrés dès la première
/// lettre sur le nom français de référence ou le nom traduit. Seul un
/// toucher choisit un pays ([onSelected]), servi ou « Bientôt » : la frappe
/// ne choisit rien. Champ vidé : [onCleared]. Aucune correspondance : texte
/// « pas disponible pour ce pays ».
///
/// Les pays de [MobileMoneyCountries.otherCurrency] (autre devise que le
/// paiement) sont listés après les pays servis, grisés et non sélectionnables,
/// avec la devise du paiement en sous-titre.
///
/// Valeurs manipulées : codes ISO alpha-2 en majuscules.
class MobileMoneyCountryField extends StatefulWidget {
  const MobileMoneyCountryField({
    super.key,
    required this.countries,
    required this.onSelected,
    required this.onCleared,
    this.initialUpcoming,
    this.currency,
  });

  final MobileMoneyCountries countries;

  /// Pays touché dans la liste, servi ou « Bientôt ».
  final ValueChanged<String> onSelected;

  /// Le champ vient d'être vidé.
  final VoidCallback onCleared;

  /// Pays « Bientôt » déjà retenu (retour sur l'écran) : la recherche
  /// reprend son nom pour que la note et le bouton gardent leur sens.
  final String? initialUpcoming;

  /// Devise imposée au paiement, citée sous les pays d'une autre devise. À
  /// défaut, celle des pays servis.
  final String? currency;

  @override
  State<MobileMoneyCountryField> createState() =>
      _MobileMoneyCountryFieldState();
}

class _MobileMoneyCountryFieldState extends State<MobileMoneyCountryField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Recherche non vide sans aucun pays : affiche le texte « pas
  /// disponible ». Notifier plutôt que `setState`, seul ce texte en dépend.
  final ValueNotifier<bool> _notFound = ValueNotifier(false);

  bool _initialized = false;

  /// Dernière recherche traitée : le contrôleur notifie aussi les simples
  /// déplacements du curseur.
  String? _lastQuery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final upcoming = widget.initialUpcoming;
    if (upcoming != null) {
      _controller.text = countryName(context.l10n, upcoming);
    }
    _lastQuery = _controller.text;
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    _notFound.dispose();
    super.dispose();
  }

  Set<String> get _availableCodes =>
      widget.countries.available.map((c) => c.country.toUpperCase()).toSet();

  Set<String> get _otherCurrencyCodes => widget.countries.otherCurrency
      .map((c) => c.country.toUpperCase())
      .where((c) => !_availableCodes.contains(c))
      .toSet();

  String? get _paymentCurrency =>
      widget.currency ??
      widget.countries.available.firstOrNull?.currency.toUpperCase();

  void _select(String code) {
    // Un pays d'une autre devise ne se choisit pas, même par la touche
    // d'envoi du clavier qui valide l'option en surbrillance.
    if (_otherCurrencyCodes.contains(code.toUpperCase())) return;
    widget.onSelected(code);
  }

  bool _isUpcoming(String code) =>
      !_availableCodes.contains(code) &&
      !_otherCurrencyCodes.contains(code) &&
      widget.countries.isUpcoming(code);

  void _onQueryChanged() {
    final query = _controller.text;
    if (query == _lastQuery) return;
    _lastQuery = query;
    final empty = query.trim().isEmpty;
    _notFound.value = !empty && _optionsFor(query).isEmpty;
    if (empty) widget.onCleared();
  }

  /// Pays servis puis pays « Bientôt », chacun trié par nom affiché.
  List<String> _optionsFor(String query) {
    final l = context.l10n;
    final available = _availableCodes;
    final otherCurrency = _otherCurrencyCodes;
    final upcoming = widget.countries.upcoming
        .map((c) => c.toUpperCase())
        .where((c) => !available.contains(c) && !otherCurrency.contains(c))
        .toSet();
    final needle = query.trim();
    final matched = needle.isEmpty
        ? null
        : CountryCatalog.search(
            needle,
            localizedName: (c) => countryName(l, c.code),
          ).map((c) => c.code).toSet();

    bool keep(String code) {
      if (matched == null || matched.contains(code)) return true;
      // Pays servi par pawaPay mais absent du catalogue de l'app : trouvé
      // par son nom affiché.
      final inCatalog = CountryCatalog.all.any((c) => c.code == code);
      return !inCatalog &&
          countryName(l, code).toLowerCase().contains(needle.toLowerCase());
    }

    int byName(String a, String b) =>
        countryName(l, a).compareTo(countryName(l, b));

    return [
      ...available.where(keep).toList()..sort(byName),
      ...otherCurrency.where(keep).toList()..sort(byName),
      ...upcoming.where(keep).toList()..sort(byName),
    ];
  }

  String _operatorsOf(String code) {
    final country = widget.countries.byCode(code);
    if (country == null) return '';
    final labels = <String>[];
    for (final o in country.operators) {
      if (!labels.contains(o.label)) labels.add(o.label);
    }
    return labels.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          displayStringForOption: (code) => countryName(l, code),
          optionsBuilder: (value) => _optionsFor(value.text),
          onSelected: _select,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
              DonyTextField(
                key: const Key('mm-country-field'),
                controller: controller,
                focusNode: focusNode,
                label: l.mobileMoneyCountryLabel,
                hint: l.mobileMoneyCountrySearchHint,
                prefixWidget: DonyIcon(
                  'search',
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSubmitted(),
              ),
          optionsViewBuilder: (context, onSelected, options) => _OptionsList(
            options: options.toList(),
            isUpcoming: _isUpcoming,
            isDisabled: _otherCurrencyCodes.contains,
            subtitleOf: (code) {
              if (_isUpcoming(code)) {
                return l.mobileMoneyCountryUpcomingSubtitle;
              }
              if (_otherCurrencyCodes.contains(code)) {
                final currency = _paymentCurrency;
                return currency == null
                    ? ''
                    : l.mobileMoneyCountryOtherCurrency(currency);
              }
              return _operatorsOf(code);
            },
            onSelected: onSelected,
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _notFound,
          builder: (context, notFound, _) => notFound
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: DonySpacing.sm,
                    left: DonySpacing.xs,
                  ),
                  child: Text(
                    l.mobileMoneyCountryNotSupported,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Liste flottante des pays, sous le champ, à sa largeur.
class _OptionsList extends StatelessWidget {
  const _OptionsList({
    required this.options,
    required this.isUpcoming,
    required this.isDisabled,
    required this.subtitleOf,
    required this.onSelected,
  });

  final List<String> options;
  final bool Function(String code) isUpcoming;
  final bool Function(String code) isDisabled;
  final String Function(String code) subtitleOf;
  final ValueChanged<String> onSelected;

  /// Cinq lignes et demie : la demie signale qu'on peut faire défiler.
  static const _maxHeight = 56.0 * 5.5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: const EdgeInsets.only(top: DonySpacing.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: DonyShadow.md,
          ),
          child: Material(
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: cs.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxHeight),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final code = options[i];
                  return _OptionRow(
                    code: code,
                    upcoming: isUpcoming(code),
                    disabled: isDisabled(code),
                    subtitle: subtitleOf(code),
                    onTap: () => onSelected(code),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.code,
    required this.upcoming,
    required this.disabled,
    required this.subtitle,
    required this.onTap,
  });

  final String code;
  final bool upcoming;

  /// Pays d'une autre devise : grisé, non sélectionnable.
  final bool disabled;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = countryName(l, code);
    final muted = upcoming || disabled;
    return Semantics(
      button: true,
      enabled: !disabled,
      child: InkWell(
        // Un pays « Bientôt » se choisit aussi : l'écran propose alors la
        // carte bancaire ou le code de recharge. Un pays d'une autre devise,
        // non.
        onTap: disabled ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDonyMinTapTarget + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.sm,
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: muted ? 0.45 : 1,
                  child: MobileMoneyCountryFlag(code: code),
                ),
                const SizedBox(width: DonySpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: muted ? cs.onSurfaceVariant : cs.onSurface,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (upcoming) ...[
                  const SizedBox(width: DonySpacing.sm),
                  _UpcomingTag(label: l.mobileMoneyCountryUpcoming),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingTag extends StatelessWidget {
  const _UpcomingTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.sm,
          vertical: DonySpacing.xxs,
        ),
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Drapeau d'un pays, ou un globe pour un code mal formé.
class MobileMoneyCountryFlag extends StatelessWidget {
  const MobileMoneyCountryFlag({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final flag = countryFlagEmoji(code);
    if (flag == null) {
      return DonyIcon(
        'globe',
        size: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return ExcludeSemantics(
      child: Text(flag, style: const TextStyle(fontSize: 22, height: 1)),
    );
  }
}
