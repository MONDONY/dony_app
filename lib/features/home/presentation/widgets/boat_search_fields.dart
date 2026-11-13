// Filtres propres au bateau de l'écran Rechercher : volume restant minimal
// (m³), prix maximal au m³ (devise du lecteur) et arrivée estimée au plus tard
// (4, 6 ou 8 semaines). Partagés par la rangée de puces de l'accueil
// (`HomeFilterChipsRow`) et par le composeur (`SearchComposerScreen`).
//
// Les valeurs saisies sont bornées comme le back ([BoatSearchLimits]) : un
// bouton « Appliquer » n'envoie jamais une valeur qu'il refuserait en 400. Un
// champ laissé vide retire le filtre.

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/utils/format_volume.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Valeur rendue par une feuille de saisie : l'enveloppe distingue « Appliquer
/// sans valeur » (le filtre est retiré, `value` nul) d'une feuille refermée
/// sans rien choisir (résultat nul, rien ne change).
typedef _Picked = ({double? value});

/// Champ de la section « VOLUME ET PRIX » : même habillage que `PriceField`,
/// ouvre la feuille de saisie au toucher.
class BoatFilterField extends StatelessWidget {
  const BoatFilterField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.iconAsset,
    required this.onTap,
  });

  /// Intitulé du champ (« VOLUME MIN »).
  final String label;

  /// Valeur affichée ; `null` = aucun filtre (« Tous »).
  final String? valueLabel;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final active = valueLabel != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.md,
          vertical: DonySpacing.md,
        ),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(DonyRadius.md),
          border: Border.all(color: active ? cs.primary : cs.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: DonySpacing.xs),
            Row(
              children: [
                DonyIcon(iconAsset, size: 14, color: cs.primary),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Text(
                    valueLabel ?? context.l10n.homeFilterFieldsAll,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      color: active ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// « ≥ 2 m³ » : valeur du champ et de la puce du volume minimal.
String boatVolumeFilterLabel(AppLocalizations l, double volumeM3) =>
    l.homeFilterBoatVolumeValue(formatVolumeM3(l, volumeM3));

/// « ≤ 600 €/m³ » : valeur du champ du prix maximal au m³, dans la devise du
/// lecteur.
String boatPriceFilterLabel(AppLocalizations l, double pricePerM3) =>
    l.homeFilterBoatPriceValue(
      l.tripPublishPerM3Value(formatPriceActive(pricePerM3)),
    );

/// Feuille du volume restant minimal, en m³ (0,1 à 9 999). [onApply] reçoit
/// `null` quand le champ est laissé vide : le filtre est retiré.
Future<void> showBoatVolumePicker(
  BuildContext context, {
  required double? volumeM3,
  required ValueChanged<double?> onApply,
}) async {
  final l = context.l10n;
  final picked = await _showNumberSheet(
    context,
    title: l.homeFilterBoatVolumeTitle,
    fieldKey: const Key('boat-filter-volume-field'),
    fieldLabel: l.homeFilterBoatVolumeFieldLabel,
    hint: l.homeFilterBoatVolumeHint,
    errorText: l.homeFilterBoatVolumeInvalid,
    initial: volumeM3 == null ? '' : _inputText(l.localeName, volumeM3),
    parse: (raw) => BoatSearchLimits.volume(readVolumeInput(raw)),
    prefixIcon: Icons.inventory_2_rounded,
  );
  if (picked != null) onApply(picked.value);
}

/// Feuille du prix maximal au m³, dans la devise du lecteur. [onApply] reçoit
/// `null` quand le champ est laissé vide : le filtre est retiré.
Future<void> showBoatPricePerM3Picker(
  BuildContext context, {
  required double? pricePerM3,
  required ValueChanged<double?> onApply,
}) async {
  final l = context.l10n;
  final picked = await _showNumberSheet(
    context,
    title: l.homeFilterBoatPriceTitle,
    fieldKey: const Key('boat-filter-price-field'),
    fieldLabel: l.homeFilterBoatPriceFieldLabel(activeCurrencySymbol),
    hint: l.homeFilterBoatPriceHint,
    errorText: l.homeFilterBoatPriceInvalid(
      formatPriceActive(BoatSearchLimits.maxPricePerM3),
    ),
    initial: pricePerM3 == null ? '' : _inputText(l.localeName, pricePerM3),
    parse: (raw) => BoatSearchLimits.pricePerM3(parsePriceInput(raw)),
    prefixIcon: Icons.sell_outlined,
  );
  if (picked != null) onApply(picked.value);
}

/// Valeur reprise dans le champ de saisie : deux décimales au plus, sans
/// séparateur de milliers (« 12,5 » en français).
String _inputText(String locale, double value) =>
    NumberFormat('#0.##', locale).format(value);

Future<_Picked?> _showNumberSheet(
  BuildContext context, {
  required String title,
  required Key fieldKey,
  required String fieldLabel,
  required String hint,
  required String errorText,
  required String initial,
  required double? Function(String raw) parse,
  required IconData prefixIcon,
}) {
  // Seul le bouton lit ce notifier, il n'est jamais réabonné après la
  // fermeture : on peut le libérer ici. Les contrôleurs de texte vivent dans le
  // `State` du contenu (voir `_NumberForm`).
  final submitNotifier = ValueNotifier<VoidCallback?>(null);
  final l = context.l10n;
  return DonyBottomSheet.show<_Picked>(
    context,
    title: title,
    stickyBottom: ValueListenableBuilder<VoidCallback?>(
      valueListenable: submitNotifier,
      builder: (_, submit, _) => DonyButton(
        key: const Key('boat-filter-apply'),
        label: l.commonApply,
        onPressed: submit,
      ),
    ),
    child: _NumberForm(
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      hint: hint,
      errorText: errorText,
      initial: initial,
      parse: parse,
      prefixIcon: prefixIcon,
      onSubmitReady: (fn) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => submitNotifier.value = fn,
      ),
    ),
  ).whenComplete(submitNotifier.dispose);
}

class _NumberForm extends StatefulWidget {
  const _NumberForm({
    required this.fieldKey,
    required this.fieldLabel,
    required this.hint,
    required this.errorText,
    required this.initial,
    required this.parse,
    required this.prefixIcon,
    required this.onSubmitReady,
  });

  final Key fieldKey;
  final String fieldLabel;
  final String hint;
  final String errorText;
  final String initial;
  final double? Function(String raw) parse;
  final IconData prefixIcon;
  final void Function(VoidCallback?) onSubmitReady;

  @override
  State<_NumberForm> createState() => _NumberFormState();
}

class _NumberFormState extends State<_NumberForm> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  /// Erreur affichée sous le champ : une saisie illisible ou hors bornes.
  final ValueNotifier<bool> _invalid = ValueNotifier<bool>(false);

  /// État du bouton, pour ne prévenir la feuille qu'à un changement.
  bool? _submittable;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validate);
    // Premier état du bouton : une saisie reprise du filtre en cours est valide.
    WidgetsBinding.instance.addPostFrameCallback((_) => _validate(force: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    _invalid.dispose();
    super.dispose();
  }

  /// Vide = retirer le filtre (valide) ; sinon la valeur doit être dans les
  /// bornes du back.
  bool get _isValid {
    final raw = _controller.text.trim();
    return raw.isEmpty || widget.parse(raw) != null;
  }

  void _validate({bool force = false}) {
    final valid = _isValid;
    _invalid.value = !valid;
    if (!force && valid == _submittable) return;
    _submittable = valid;
    widget.onSubmitReady(valid ? _submit : null);
  }

  void _submit() {
    if (!_isValid) return;
    final raw = _controller.text.trim();
    final _Picked picked = (value: raw.isEmpty ? null : widget.parse(raw));
    Navigator.of(context, rootNavigator: true).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _invalid,
          builder: (_, invalid, _) => DonyTextField(
            key: widget.fieldKey,
            controller: _controller,
            label: widget.fieldLabel,
            prefixIcon: widget.prefixIcon,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // Deux décimales au plus, le back en accepte quatre.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]\d{0,2})?')),
            ],
            errorText: invalid ? widget.errorText : null,
          ),
        ),
        const SizedBox(height: DonySpacing.sm),
        Text(
          widget.hint,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Feuille de l'arrivée estimée au plus tard : « Sous 4, 6 ou 8 semaines ».
/// [onApply] reçoit `null` quand aucune fenêtre n'est retenue (la fenêtre déjà
/// choisie a été retouchée) : le filtre est retiré. Une feuille refermée sans
/// « Appliquer » ne change rien.
Future<void> showBoatArrivalPicker(
  BuildContext context, {
  required int? weeks,
  required ValueChanged<int?> onApply,
}) async {
  // Seul un geste de l'utilisateur écrit dans ce notifier : on peut le libérer
  // à la fermeture de la feuille.
  final selected = ValueNotifier<int?>(BoatSearchLimits.weeks(weeks));
  final l = context.l10n;
  final picked = await DonyBottomSheet.show<({int? weeks})>(
    context,
    title: l.homeFilterBoatArrivalTitle,
    child: ValueListenableBuilder<int?>(
      valueListenable: selected,
      builder: (ctx, current, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArrivalWindowChips(
            selected: current,
            onChanged: (value) => selected.value = value,
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(
            ctx.l10n.homeFilterBoatArrivalHelp,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    stickyBottom: Builder(
      builder: (ctx) => DonyButton(
        key: const Key('boat-filter-apply'),
        label: ctx.l10n.commonApply,
        onPressed: () => Navigator.of(ctx).pop((weeks: selected.value)),
      ),
    ),
  ).whenComplete(selected.dispose);
  if (picked != null) onApply(picked.weeks);
}

/// Les trois fenêtres d'arrivée sous forme de pastilles. Retoucher la fenêtre
/// retenue la retire.
class ArrivalWindowChips extends StatelessWidget {
  const ArrivalWindowChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(
      spacing: DonySpacing.sm,
      runSpacing: DonySpacing.sm,
      children: [
        for (final weeks in BoatSearchLimits.arrivalWeeks)
          QuickChip(
            key: Key('boat-arrival-$weeks'),
            label: l.homeFilterBoatArrivalOption(weeks),
            iconAsset: 'clock',
            active: selected == weeks,
            onChanged: (on) => onChanged(on ? weeks : null),
          ),
      ],
    );
  }
}
