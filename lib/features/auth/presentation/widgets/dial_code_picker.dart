import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/phone/phone_country.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Liste de choix de l'indicatif pays, avec recherche.
///
/// La recherche n'est pas un ornement : le sélecteur est passé de dix à
/// trente-neuf entrées le jour où il a cessé de diverger du catalogue pays.
/// Faire défiler l'Europe entière pour atteindre le Sénégal serait une
/// régression pour les corridors les plus utilisés.
class DialCodePicker extends StatefulWidget {
  const DialCodePicker({
    super.key,
    required this.selectedCode,
    required this.onSelected,
  });

  /// Code ISO du pays actuellement retenu.
  ///
  /// C'est bien le code ISO et non l'indicatif : le Canada et les États-Unis
  /// partagent `+1`, et cocher les deux lignes serait faux.
  final String selectedCode;

  final ValueChanged<PhoneCountry> onSelected;

  @override
  State<DialCodePicker> createState() => _DialCodePickerState();
}

class _DialCodePickerState extends State<DialCodePicker> {
  /// Le contrôleur vit dans le `State` du contenu, jamais dans le `show()` :
  /// la feuille reste affichée pendant son animation de sortie, et un
  /// contrôleur déjà libéré ferait planter la frame du clavier qui se replie.
  final _searchController = TextEditingController();
  final _query = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _query.value = _searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Replie les accents pour que « senegal » trouve Sénégal.
  static String _fold(String value) {
    const from = 'àâäçéèêëîïôöùûü';
    const to = 'aaaceeeeiioouuu';
    final buffer = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString();
  }

  List<PhoneCountry> _filtered(String query) {
    final needle = _fold(query);
    if (needle.isEmpty) return kPhoneCountries;
    return kPhoneCountries
        .where(
          (c) =>
              _fold(c.name).contains(needle) ||
              c.dialCode.contains(needle) ||
              c.code.toLowerCase() == needle,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('dial_code_search'),
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher un pays ou un indicatif',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(DonySpacing.md),
              child: DonyIcon('search', color: cs.onSurfaceVariant, size: 18),
            ),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DonyRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              final countries = _filtered(query);
              if (countries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(DonySpacing.xl),
                  child: Text(
                    'Aucun pays ne correspond',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final c = countries[index];
                  return Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      leading: Text(
                        c.flag,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(
                        '${c.name} (${c.dialCode})',
                        style: tt.titleMedium,
                      ),
                      trailing: widget.selectedCode == c.code
                          ? DonyIcon('check', color: cs.primary)
                          : null,
                      onTap: () => widget.onSelected(c),
                    ),
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
