import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/core/currency/country_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Ouvre la liste des pays de l'app ([CountryCatalog.all]) dans une
/// [DonyBottomSheet], avec recherche et sections par zone. Rend le code ISO
/// choisi, ou `null` si la feuille est fermée sans choix.
Future<String?> showCountryPicker(
  BuildContext context, {
  required String title,
  String? selectedCode,
  bool showCurrency = false,
  bool showFlag = true,
}) {
  return DonyBottomSheet.show<String>(
    context,
    title: title,
    heightFraction: 0.85,
    child: CountryPickerList(
      selectedCode: selectedCode,
      showCurrency: showCurrency,
      showFlag: showFlag,
    ),
  );
}

/// Liste des pays du catalogue, filtrée par un champ de recherche (nom de
/// référence ou nom traduit, sans accents) et groupée par zone : 38 entrées à
/// plat seraient illisibles.
///
/// Un [selectedCode] hors catalogue (ex. `GN` déjà enregistré, ou un pays
/// renvoyé par la recherche d'adresse) reste affiché en tête, coché : le
/// sélecteur ne doit jamais faire disparaître la valeur courante.
///
/// Le choix ferme la feuille en rendant le code ISO au `Future` de
/// [DonyBottomSheet.show].
class CountryPickerList extends StatefulWidget {
  const CountryPickerList({
    super.key,
    required this.selectedCode,
    this.showCurrency = false,
    this.showFlag = true,
  });

  final String? selectedCode;

  /// Affiche la devise du pays sous son nom (réglages : la devise dépend du
  /// pays de résidence).
  final bool showCurrency;

  /// Affiche le drapeau en tête de ligne.
  final bool showFlag;

  @override
  State<CountryPickerList> createState() => _CountryPickerListState();
}

class _CountryPickerListState extends State<CountryPickerList> {
  final _controller = TextEditingController();
  List<CountryZoneGroup> _results = CountryCatalog.groupedSearch('');

  // `l` n'est connu qu'à partir de `didChangeDependencies` (les délégués ne
  // sont pas prêts en `initState`) : on le garde ici pour que la recherche
  // trouve aussi le nom localisé, et on relance le calcul si la langue change.
  AppLocalizations? _l;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshResults);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l = context.l10n;
    _refreshResults();
  }

  void _refreshResults() {
    final l = _l;
    setState(() {
      _results = CountryCatalog.groupedSearch(
        _controller.text,
        localizedName: l == null ? null : (c) => countryName(l, c.code),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Code courant hors catalogue, à garder visible en tête de liste tant que
  /// la recherche est vide.
  String? get _outsideCatalog {
    final code = widget.selectedCode?.trim().toUpperCase();
    if (code == null || code.isEmpty || CountryCatalog.byCode(code) != null) {
      return null;
    }
    return _controller.text.trim().isEmpty ? code : null;
  }

  Widget? _flag(String code) {
    if (!widget.showFlag) {
      return null;
    }
    final flag = countryFlagEmoji(code);
    if (flag == null) {
      return const DonyIcon('globe', size: 22);
    }
    return Text(flag, style: const TextStyle(fontSize: 22));
  }

  Widget _tile(BuildContext context, String code, {String? subtitle}) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    final isSelected = widget.selectedCode?.trim().toUpperCase() == code;
    return ListTile(
      leading: _flag(code),
      title: Text(
        countryName(l, code),
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: isSelected ? DonyIcon('check', color: cs.primary) : null,
      onTap: () => Navigator.of(context).pop(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final outside = _outsideCatalog;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyTextField(
          controller: _controller,
          hint: l.prefsCountrySearchHint,
          prefixIcon: Icons.search,
        ),
        const SizedBox(height: DonySpacing.md),
        if (outside != null) _tile(context, outside),
        if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DonySpacing.xl),
            child: Text(
              l.prefsCountryNotFound,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        else
          for (final group in _results) ...[
            Semantics(
              header: true,
              container: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  DonySpacing.base,
                  DonySpacing.md,
                  DonySpacing.base,
                  DonySpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    countryZoneLabel(l, group.zone).toUpperCase(),
                    style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
            for (final country in group.countries)
              _tile(
                context,
                country.code,
                subtitle: widget.showCurrency
                    ? '${country.currency.code} · ${country.currency.symbol}'
                    : null,
              ),
          ],
      ],
    );
  }
}
