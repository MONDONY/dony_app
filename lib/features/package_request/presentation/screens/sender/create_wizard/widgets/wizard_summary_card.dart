import 'package:dony/core/design/design_system.dart';
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
        ],
      ),
    );
  }

  Widget _divider(ColorScheme cs) =>
      Divider(height: 12, thickness: 1, color: cs.outlineVariant);

  Widget _line(BuildContext context, String label, String value) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: DonyColors.textMuted,
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
              color: DonyColors.textPrimary,
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

  String _dateText(PackageRequestFormState s) {
    if (s.desiredDate == null) return '-';
    final f = DateFormat('d MMM. y', 'fr_FR').format(s.desiredDate!);
    final tol = s.dateToleranceDays ?? 0;
    return tol == 0 ? f : '$f ±${tol}j';
  }

  String _packageText(PackageRequestFormState s) {
    final size = s.parcelSize?.wireName ?? '-';
    final w = s.weightKg;
    final wStr = w == null
        ? ''
        : ' · ${w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1)} kg';
    final cat = s.categories.isEmpty ? '' : ' · ${s.categories.first}';
    return '$size$wStr$cat';
  }
}
