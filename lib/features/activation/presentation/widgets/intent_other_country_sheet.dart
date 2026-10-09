import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/utils/text_search.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/activation/bloc/intent_cubit.dart';
import 'package:dony/features/activation/presentation/widgets/intent_form.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Pays proposés derrière la puce « Autre » (FLUTTER-H9) : le reste du
/// catalogue serveur (`CountryCatalog.java`), soit les 24 pays EUR/CHF/GBP/
/// CAD/USD, une fois retirés les 14 pays UEMOA + CEMAC déjà en puces.
final List<String> kIntentOtherCountries = [
  for (final country in CountryCatalog.all)
    if (!kIntentDestinations.contains(country.code)) country.code,
];

/// Vrai si [code] est un pays précis choisi derrière « Autre ».
bool isIntentOtherCountry(String? code) =>
    code != null && kIntentOtherCountries.contains(code);

/// [kIntentOtherCountries] triés par nom dans la langue de [l], accents
/// ignorés.
List<String> orderedIntentOtherCountries(AppLocalizations l) =>
    [...kIntentOtherCountries]..sort(
      (a, b) => normalizeSearch(
        countryName(l, a),
      ).compareTo(normalizeSearch(countryName(l, b))),
    );

/// Feuille ouverte par la puce « Autre ». Renvoie le code ISO2 choisi,
/// [kIntentOtherDestination] pour « Mon pays n'est pas dans la liste », ou
/// `null` si elle est fermée sans choix.
abstract final class IntentOtherCountrySheet {
  static Future<String?> show(BuildContext context, {String? selectedCode}) =>
      DonyBottomSheet.show<String>(
        context,
        title: context.l10n.intentOtherCountrySheetTitle,
        heightFraction: 0.85,
        child: IntentOtherCountryList(selectedCode: selectedCode),
      );
}

/// Recherche + liste des [kIntentOtherCountries]. Le contrôleur de recherche
/// vit dans ce `State` (jamais disposé au `pop`, cf. FLUTTER-18) et la liste
/// se recalcule par [ValueListenableBuilder], sans `setState`.
class IntentOtherCountryList extends StatefulWidget {
  const IntentOtherCountryList({super.key, this.selectedCode});

  final String? selectedCode;

  @override
  State<IntentOtherCountryList> createState() => _IntentOtherCountryListState();
}

class _IntentOtherCountryListState extends State<IntentOtherCountryList> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _filter(AppLocalizations l, String query) {
    final needle = normalizeSearch(query.trim());
    final ordered = orderedIntentOtherCountries(l);
    if (needle.isEmpty) return ordered;
    return ordered.where((code) {
      // Nom affiché ou nom français de référence : « Germany » comme
      // « Allemagne » trouvent DE.
      final reference = CountryCatalog.byCode(code)?.name ?? code;
      return normalizeSearch(countryName(l, code)).contains(needle) ||
          normalizeSearch(reference).contains(needle);
    }).toList();
  }

  void _pick(String code) => Navigator.of(context).pop(code);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyTextField(
          key: const Key('intent-other-country-search'),
          controller: _controller,
          hint: l.prefsCountrySearchHint,
          prefixIcon: Icons.search,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: DonySpacing.md),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final results = _filter(l, value.text);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DonySpacing.xl,
                    ),
                    child: Text(
                      l.prefsCountryNotFound,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final code in results)
                  ListTile(
                    key: Key('intent-other-country-$code'),
                    leading: Text(
                      phoneCountryForCode(code)?.flag ?? '',
                      style: tt.titleLarge,
                    ),
                    title: Text(countryName(l, code)),
                    selected: widget.selectedCode == code,
                    trailing: widget.selectedCode == code
                        ? DonyIcon('check', color: cs.primary)
                        : null,
                    onTap: () => _pick(code),
                  ),
                const Divider(height: DonySpacing.lg),
                ListTile(
                  key: const Key('intent-other-country-not-listed'),
                  leading: Icon(Icons.public, color: cs.onSurfaceVariant),
                  title: Text(l.intentOtherCountryNotListed),
                  selected: widget.selectedCode == kIntentOtherDestination,
                  trailing: widget.selectedCode == kIntentOtherDestination
                      ? DonyIcon('check', color: cs.primary)
                      : null,
                  onTap: () => _pick(kIntentOtherDestination),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
