import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Pays proposés pour la résidence fiscale : la liste du back
/// (`residenceCountryChoices`, yadony-back #730), sinon le catalogue de l'app
/// (back sans cette liste).
List<String> taxResidenceChoices(List<String> fromBack) => fromBack.isNotEmpty
    ? fromBack
    : [for (final c in CountryCatalog.all) c.code];

/// Ouvre la liste des pays de résidence dans une [DonyBottomSheet], avec
/// recherche. Rend le code ISO choisi, ou `null` si la feuille est fermée sans
/// choix.
///
/// Liste séparée du sélecteur des Réglages : elle contient des pays de
/// l'Union absents du catalogue des devises (BG, CZ, DK, HU, PL, RO, SE), qui
/// ne servent qu'à la déclaration fiscale.
Future<String?> showTaxResidencePicker(
  BuildContext context, {
  required String title,
  required List<String> choices,
  String? selectedCode,
}) => DonyBottomSheet.show<String>(
  context,
  title: title,
  heightFraction: 0.85,
  analyticsName: 'tax-info/residence-country',
  child: TaxResidencePickerList(choices: choices, selectedCode: selectedCode),
);

/// Liste triée par nom affiché, filtrée sans accents ni casse. Le contrôleur
/// de recherche vit dans ce `State` (disposé dans `dispose()`) ; le filtre se
/// recalcule par [ValueListenableBuilder], sans `setState`.
class TaxResidencePickerList extends StatefulWidget {
  const TaxResidencePickerList({
    super.key,
    required this.choices,
    this.selectedCode,
  });

  final List<String> choices;
  final String? selectedCode;

  @override
  State<TaxResidencePickerList> createState() => _TaxResidencePickerListState();
}

class _TaxResidencePickerListState extends State<TaxResidencePickerList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ'; // i18n-ignore : table
  static const _to = 'aaaaaaceeeeiiiinooooouuuuyyoa';

  static String _fold(String value) {
    final buffer = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = _from.indexOf(char);
      buffer.write(index >= 0 ? _to[index] : char);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final named = [
      for (final code in widget.choices) (code, countryName(l, code)),
    ]..sort((a, b) => _fold(a.$2).compareTo(_fold(b.$2)));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DonyTextField(
          key: const Key('tax_residence_search'),
          controller: _search,
          hint: l.prefsCountrySearchHint,
          prefixIcon: Icons.search,
          autocorrect: false,
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: DonySpacing.sm),
        Flexible(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _search,
            builder: (context, value, _) {
              final needle = _fold(value.text);
              final shown = needle.isEmpty
                  ? named
                  : named
                        .where(
                          (e) =>
                              _fold(e.$2).contains(needle) ||
                              e.$1.toLowerCase() == needle,
                        )
                        .toList();
              return ListView.builder(
                shrinkWrap: true,
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final (code, name) = shown[i];
                  final selected = code == widget.selectedCode;
                  return ListTile(
                    key: Key('tax_residence_$code'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(name),
                    trailing: selected
                        ? DonyIcon('check', color: cs.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(code),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
