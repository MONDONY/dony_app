import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte récap à l'étape 3 — fond primaryContainer (bleu léger).
class WizardSummaryCard extends StatelessWidget {
  const WizardSummaryCard({super.key, required this.state});

  final PackageRequestFormState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          _line(context, 'Trajet', _corridorText(state)),
          _divider(cs),
          _line(context, 'Date', _dateText(state)),
          if (state.transportMode != null) ...[
            _divider(cs),
            _line(context, 'Transport', state.transportMode!.label),
          ],
          _divider(cs),
          _line(context, 'Colis', _packageText(state)),
          if (state.categories.isNotEmpty) ...[
            _divider(cs),
            _line(context, 'Contenu', _categoriesText(state)),
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

  String _dateText(PackageRequestFormState s) =>
      formatDesiredDate(s.desiredDate, s.dateToleranceDays);

  /// Poids seul. La taille n'est plus affichée : elle n'est pas saisie par
  /// l'expéditeur (l'étape 2 la déduit du poids pour les filtres de recherche),
  /// et le récap la sortait telle quelle du fil, en « MEDIUM ».
  String _packageText(PackageRequestFormState s) {
    final w = s.weightKg;
    return w == null ? '-' : formatWeightKg(w);
  }

  /// Toutes les catégories, pas seulement la première : le récap en affichait
  /// une seule et laissait croire que les autres avaient été perdues.
  String _categoriesText(PackageRequestFormState s) =>
      s.categories.isEmpty ? '-' : s.categories.join(', ');
}

/// Date souhaitée et sa tolérance, en un libellé.
///
/// Le récap de l'étape 3 et l'aperçu qui s'ouvre par-dessus rendaient la même
/// donnée avec deux motifs différents, à deux secondes d'intervalle.
String formatDesiredDate(
  DateTime? date,
  int? toleranceDays, {
  bool long = false,
}) {
  if (date == null) return '-';
  final f = DateFormat(long ? 'd MMMM y' : 'd MMM. y', 'fr_FR').format(date);
  final tol = toleranceDays ?? 0;
  return tol == 0 ? f : '$f ±${tol}j';
}
