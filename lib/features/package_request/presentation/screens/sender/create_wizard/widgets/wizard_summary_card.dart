import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/content_categories/presentation/content_category_labels.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte récap à l'étape 3 — fond primaryContainer (bleu léger).
class WizardSummaryCard extends StatelessWidget {
  const WizardSummaryCard({super.key, required this.state});

  final PackageRequestFormState state;

  @override
  Widget build(BuildContext context) {
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
          if (state.transportMode != null) ...[
            _divider(cs),
            _line(
              context,
              l.requestCreateRecapTransport,
              state.transportMode!.label(l),
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

  Widget _line(BuildContext context, String label, String value) {
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

/// Date souhaitée et sa tolérance, en un libellé.
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
  if (date == null) return '-';
  final locale = l.localeName;
  final f = long
      ? DateFormat.yMMMMd(locale).format(date)
      : (locale == 'en'
            ? DateFormat.yMMMd(locale).format(date)
            : DateFormat('d MMM. y', locale).format(date));
  final tol = toleranceDays ?? 0;
  return tol == 0 ? f : '$f ${toleranceCompactLabel(l, tol)}';
}
