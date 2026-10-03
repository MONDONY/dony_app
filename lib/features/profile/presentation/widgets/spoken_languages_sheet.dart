import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/presentation/profile_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Liste déroulante des langues parlées (FLUTTER-9Z) : les langues les plus
/// parlées au monde ([kSpokenLanguages]), une recherche, et « Autre langue »
/// pour en saisir une absente de la liste.
///
/// Rend la sélection complète, dans l'ordre choisi, ou `null` si la feuille
/// est refermée sans valider. Les langues déjà au profil hors de la liste
/// (saisies libres) restent cochées et proposées.
abstract final class SpokenLanguagesSheet {
  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> selected,
  }) {
    final selection = ValueNotifier<List<String>>(List.of(selected));
    final initialCustom = selected.where((v) => !kSpokenLanguages.contains(v));
    return DonyBottomSheet.show<List<String>>(
      context,
      title: context.l10n.profileEditLanguagesFieldLabel,
      heightFraction: 0.85,
      stickyBottom: Builder(
        builder: (ctx) => DonyButton(
          key: const Key('spoken-languages-validate'),
          label: ctx.l10n.profileLanguagesSheetValidate,
          onPressed: () {
            final result = selection.value;
            _track(result);
            Navigator.of(ctx).pop(result);
          },
        ),
      ),
      child: _SpokenLanguagesBody(
        selection: selection,
        initialCustom: initialCustom.toList(),
      ),
    ).whenComplete(selection.dispose);
  }

  /// Choix sans état métier, tracé à la validation de la feuille.
  static void _track(List<String> result) {
    if (!getIt.isRegistered<AnalyticsService>()) return;
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.profileLanguagesPicked,
        properties: {
          'count': result.length,
          'custom_count': result
              .where((v) => !kSpokenLanguages.contains(v))
              .length,
        },
      ),
    );
  }
}

class _SpokenLanguagesBody extends StatefulWidget {
  const _SpokenLanguagesBody({
    required this.selection,
    required this.initialCustom,
  });

  final ValueNotifier<List<String>> selection;
  final List<String> initialCustom;

  @override
  State<_SpokenLanguagesBody> createState() => _SpokenLanguagesBodyState();
}

/// État purement local à la feuille (recherche, saisie « Autre ») : rien de
/// métier, la sélection remonte par le [ValueNotifier] à la validation.
class _SpokenLanguagesBodyState extends State<_SpokenLanguagesBody> {
  final _otherCtrl = TextEditingController();
  late final List<String> _options = [
    ...kSpokenLanguages,
    ...widget.initialCustom,
  ];
  String _query = '';
  bool _otherOpen = false;

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _toggle(String value) {
    final current = widget.selection.value;
    widget.selection.value = current.contains(value)
        ? (List.of(current)..remove(value))
        : [...current, value];
  }

  void _addOther() {
    final value = _otherCtrl.text.trim();
    if (value.isEmpty) return;
    // Même langue déjà proposée (casse ou libellé traduit) : on la coche.
    final l = context.l10n;
    final existing = _options.firstWhere(
      (o) =>
          o.toLowerCase() == value.toLowerCase() ||
          spokenLanguageLabel(l, o).toLowerCase() == value.toLowerCase(),
      orElse: () => '',
    );
    final pick = existing.isEmpty ? value : existing;
    setState(() {
      if (existing.isEmpty) _options.add(pick);
      _otherCtrl.clear();
      _otherOpen = false;
      _query = '';
    });
    if (!widget.selection.value.contains(pick)) _toggle(pick);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? _options
        : _options
              .where(
                (o) =>
                    spokenLanguageLabel(l, o).toLowerCase().contains(q) ||
                    o.toLowerCase().contains(q),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg,
        0,
        DonySpacing.lg,
        DonySpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DonySearchField(
            hint: l.profileLanguagesSheetSearchHint,
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: DonySpacing.sm),
          ValueListenableBuilder<List<String>>(
            valueListenable: widget.selection,
            builder: (context, selected, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in visible)
                  CheckboxListTile(
                    key: ValueKey('spoken-language-$option'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(spokenLanguageLabel(l, option)),
                    value: selected.contains(option),
                    onChanged: (_) => _toggle(option),
                  ),
              ],
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
              child: Text(
                l.profileLanguagesSheetNoMatch,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          const Divider(height: DonySpacing.xl),
          if (!_otherOpen)
            ListTile(
              key: const Key('spoken-language-other'),
              contentPadding: EdgeInsets.zero,
              leading: DonyIcon('plus', color: cs.primary, size: 20),
              title: Text(
                l.profileLanguagesSheetOther,
                style: TextStyle(color: cs.primary),
              ),
              onTap: () => setState(() {
                _otherOpen = true;
                // La recherche sans résultat sert de point de départ.
                if (visible.isEmpty) _otherCtrl.text = _query.trim();
              }),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('spoken-language-other-field'),
                    controller: _otherCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        kSpokenLanguageMaxLength,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: l.profileLanguagesSheetOtherHint,
                    ),
                    onSubmitted: (_) => _addOther(),
                  ),
                ),
                const SizedBox(width: DonySpacing.sm),
                TextButton(
                  key: const Key('spoken-language-other-add'),
                  onPressed: _addOther,
                  child: Text(l.profileLanguagesSheetOtherAdd),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
