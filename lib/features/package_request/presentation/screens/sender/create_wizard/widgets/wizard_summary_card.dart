import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/widgets/wizard_palette.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte récap à l'étape 3 — fond primaryContainer (bleu léger).
class WizardSummaryCard extends StatelessWidget {
  const WizardSummaryCard({super.key, required this.state}) : compact = false;

  /// Version sur une seule ligne (trajet · poids · contenu) de l'étape « Le
  /// prix » : même information utile, une fraction de la hauteur.
  const WizardSummaryCard.compact({super.key, required this.state})
    : compact = true;

  final PackageRequestFormState state;
  final bool compact;

  Widget _compactRow(BuildContext context) {
    final p = WizardPalette.of(context);
    final l = context.l10n;
    final weight = state.weightKg;
    final style = WizardPalette.text(
      size: 11.5,
      weight: FontWeight.w400,
      color: p.n600,
    );
    // (texte, peut céder de la place) : le trajet et le contenu s'abrègent en
    // points de suspension, le poids garde la sienne.
    final items = <(Widget, bool)>[
      (
        Text(
          _corridorText(state),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontWeight: FontWeight.w700, color: p.n800),
        ),
        true,
      ),
      if (weight != null)
        (Text(formatWeightKg(l, weight), maxLines: 1, style: style), false),
      if (state.categories.isNotEmpty)
        (
          Text(
            _categoriesText(l, state),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          true,
        ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: p.blue50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.summaryBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('·', style: style.copyWith(color: p.dot)),
              ),
            if (items[i].$2) Flexible(child: items[i].$1) else items[i].$1,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _compactRow(context);
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(context, l.requestCreateRecapTrip, _corridorText(state)),
          _divider(cs),
          _line(context, l.requestCreateDateFieldLabel, _dateText(l, state)),
          // « Peu importe » est un choix : la ligne reste, avec l'icône neutre.
          // Un mode jamais choisi (ni l'un ni l'autre) n'en a pas.
          if (state.transportMode != null || state.transportModeAny) ...[
            _divider(cs),
            _line(
              context,
              l.requestCreateRecapTransport,
              state.transportMode?.label(l) ?? l.requestCreateTransportAny,
              iconAsset:
                  state.transportMode?.iconAsset ?? kNeutralTripIconAsset,
            ),
          ],
          _divider(cs),
          _line(context, l.requestCreateRecapPackage, _packageText(l, state)),
          if (state.categories.isNotEmpty) ...[
            _divider(cs),
            _line(
              context,
              l.requestCreateContentLabel,
              _categoriesText(l, state),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) =>
      Divider(height: 12, thickness: 1, color: cs.outlineVariant);

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    String? iconAsset,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (iconAsset != null) ...[
                DonyIcon(iconAsset, size: 14, color: cs.onSurface),
                const SizedBox(width: DonySpacing.xs + 2),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: tt.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _corridorText(PackageRequestFormState s) {
    final dep = s.departureCity ?? '-';
    final arr = s.arrivalCity ?? '-';
    return '$dep → $arr';
  }

  String _dateText(AppLocalizations l, PackageRequestFormState s) =>
      formatDesiredDate(l, s.desiredDate, s.dateToleranceDays);

  /// Poids seul. La taille n'est plus affichée : elle n'est pas saisie par
  /// l'expéditeur (l'étape 2 la déduit du poids pour les filtres de recherche),
  /// et le récap la sortait telle quelle du fil, en « MEDIUM ».
  String _packageText(AppLocalizations l, PackageRequestFormState s) {
    final w = s.weightKg;
    return w == null ? '-' : formatWeightKg(l, w);
  }

  /// Toutes les catégories, pas seulement la première : le récap en affichait
  /// une seule et laissait croire que les autres avaient été perdues.
  ///
  /// Le libellé AFFICHÉ passe par [contentCategoryDisplayName] : la valeur
  /// brute (envoyée au serveur, comparée dans [PackageRequestFormState])
  /// reste [s.categories] telle quelle.
  String _categoriesText(AppLocalizations l, PackageRequestFormState s) =>
      s.categories.isEmpty
      ? '-'
      : s.categories.map((c) => contentCategoryDisplayName(l, c)).join(', ');
}

/// Date souhaitée et sa tolérance, en un libellé (« Date flexible » sans date).
///
/// Le récap de l'étape 3 et l'aperçu qui s'ouvre par-dessus rendaient la même
/// donnée avec deux motifs différents, à deux secondes d'intervalle.
///
/// - `long: true` (« d MMMM y ») : le squelette intl `yMMMMd` rend
///   exactement le même texte en français (mois en toutes lettres, pas de
///   point d'abréviation), il est donc utilisé pour les deux langues.
/// - `long: false` (« d MMM. y ») : `yMMMd` ajoute un point d'abréviation de
///   moins en français (« 6 oct. 2026 » au lieu de « 6 oct.. 2026 »). Le
///   motif fixe est donc conservé pour le français, comme `_formatPickedDate`
///   dans `step_1_trajet_colis.dart`, et le squelette est utilisé pour
///   l'anglais.
String formatDesiredDate(
  AppLocalizations l,
  DateTime? date,
  int? toleranceDays, {
  bool long = false,
}) {
  // Demande sans date : « Date flexible », jamais un tiret ni « null ».
  if (date == null) return l.requestDateFlexible;
  final locale = l.localeName;
  final f = long
      ? DateFormat.yMMMMd(locale).format(date)
      : (locale == 'en'
            ? DateFormat.yMMMd(locale).format(date)
            : DateFormat('d MMM. y', locale).format(date));
  final tol = toleranceDays ?? 0;
  return tol == 0 ? f : '$f ${toleranceCompactLabel(l, tol)}';
}
